open! Import
open! Core
open Mcp

module Client = struct
  type _ Effect.t +=
    | Insufficient_server_capability : string -> 'a Effect.t
    | Invalid_response_schema : 'a Effect.t

  module Connection = struct
    type t =
      (* sink to server and response reader *)
      | Stdio of (Eio_unix.sink_ty Eio.Std.r * Eio.Buf_read.t)

    let from_stdio ~stdin ~stdout =
      let reader = Eio.Buf_read.of_flow ~max_size:4096 stdout in
      Stdio (stdin, reader)

    let read_response_reader reader =
      Eio.Buf_read.line reader
      |> Import.tap ~f:(Eio.traceln "received:\n   %s")
      |> Yojson.Safe.from_string |> Jsonrpc.Response.t_of_yojson

    let read_response = function
      | Stdio (_, reader) -> read_response_reader reader

    let send_to_flow flow msg =
      let module Write = Eio.Buf_write in
      let content = Yojson.Safe.to_string ~std:true msg in
      Eio.traceln "sending:\n   %s" content ;
      Write.with_flow flow (fun w ->
          Write.string w content ; Write.char w '\n' )

    let write_message = function Stdio (stdin, _) -> send_to_flow stdin

    let send_request connection request =
      Jsonrpc.Request.yojson_of_t request |> write_message connection

    let notify connection notification =
      Jsonrpc.Notification.yojson_of_t notification
      |> write_message connection
  end

  type t =
    { id: int ref
    ; connection: Connection.t
    ; server_capabilities: Capabilities.Server.t }

  let assert_server_cap ~cap t =
    if Stdlib.List.mem_assoc cap t.server_capabilities then ()
    else
      Effect.perform
        (Insufficient_server_capability
           (Capabilities.Server.string_of_key cap) )

  let new_id t = incr t.id ; `Int !(t.id)

  let close t =
    match t.connection with Stdio (stdin, _) -> Eio.Flow.close stdin

  let create_request t ~method_ ~params =
    let id = new_id t in
    match params with
    | None -> Jsonrpc.Request.create ~id ~method_ ()
    | Some params -> Jsonrpc.Request.create ~id ~method_ ~params ()

  let handle_result ~decode raw_result =
    match raw_result with
    | Error error -> raise (Jsonrpc_error error)
    | Ok raw_response -> (
      try decode raw_response
      with Ppx_yojson_conv_lib__Yojson_conv.Of_yojson_error _ ->
        Effect.perform Invalid_response_schema )

  let exchange_sync ~decode connection request =
    Connection.send_request connection request ;
    let {id= _; result= raw_result} : Jsonrpc.Response.t =
      Connection.read_response connection
    in
    handle_result ~decode raw_result

  let initialize ~params connection =
    let id = `Int 1 in
    let open Initialization in
    let {protocol_version; capabilities= server_capabilities; server_info} =
      Jsonrpc.Request.create ~id ~method_ ~params:(encode_params params) ()
      |> exchange_sync ~decode:Initialization.result_of_yojson connection
    in
    Eio.traceln "MCP version on the server: %s" protocol_version ;
    Eio.traceln "server info: %s" (Server_info.show server_info) ;
    Jsonrpc.Notification.create ~method_:"notifications/initialized" ()
    |> Connection.notify connection ;
    {id= ref 0; connection; server_capabilities}

  let resource_list ~params t =
    let open Resource_list in
    assert_server_cap ~cap t ;
    create_request t ~method_ ~params:(encode_params params)
    |> exchange_sync ~decode:decode_result t.connection
end
