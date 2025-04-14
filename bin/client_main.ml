open Mcp_example
open! Core
module Client = Mcp_eio.Client

let client_info : Mcp.Client_info.t =
  {name= "ocaml-mcp-example"; version= "0.1.0"}

let capabilities : Mcp.Capabilities.Client.t =
  [(`roots, [(`listChanged, true)]); (`sampling, [])]

exception Skip_phase

let try_server_cap f =
  let open Effect.Deep in
  let open Client in
  match_with f ()
    { effc=
        (fun (type a) (eff : a Effect.t) ->
          match eff with
          | Insufficient_server_capability cap_name ->
              Some
                (fun (k : (a, _) continuation) ->
                  Eio.traceln
                    "The server needs to have `%s` capability, which it \
                     doesn't"
                    cap_name ;
                  discontinue k Skip_phase )
          | Invalid_response_schema ->
              Some
                (fun (k : (a, _) continuation) ->
                  Eio.traceln
                    "The server response conforms to JSON-RPC, but the \
                     schema mismatches. Is the server using a wrong schema?" ;
                  discontinue k Skip_phase )
          | _ -> None )
    ; exnc=
        (function
        | Skip_phase ->
            Eio.traceln "Skipping the phase" ;
            ()
        | e -> raise e )
    ; retc= (fun a -> a) }

let init_stdio ~sw ~env command_and_args =
  let open Eio in
  Eio.traceln "starting the server" ;
  let child_stdin, server_in = Eio_unix.pipe sw in
  let server_out, child_stdout = Eio_unix.pipe sw in
  let proc_mgr = Stdenv.process_mgr env in
  let server_proc =
    Eio.Process.spawn ~sw proc_mgr command_and_args ~stdin:child_stdin
      ~stdout:child_stdout
  in
  let open Mcp.Initialization in
  let params = {capabilities; client_info} in
  let client =
    Client.Connection.from_stdio ~stdin:server_in ~stdout:server_out
    |> Client.initialize ~params
  in
  (client, server_proc)

let inspect_server client =
  let open Eio in
  let resource_list () =
    let open Mcp.Resource_list in
    let params = Some {cursor= None} in
    let {resources; next_cursor= _} = Client.resource_list ~params client in
    Eio.traceln "Returned %d items" (List.length resources)
  in
  try_server_cap @@ fun () -> resource_list () ; Client.close client

let () =
  let args =
    match Array.to_list (Sys.get_argv ()) with
    | [] -> failwith "impossible error"
    | _ :: rest -> rest
  in
  Eio_main.run
  @@ fun env ->
  let open Eio in
  Eio.traceln "args: %s" (String.concat ~sep:" " args) ;
  Switch.run
  @@ fun sw ->
  let client, server_proc = init_stdio ~sw ~env args in
  Fiber.all
    [ (fun () -> inspect_server client)
    ; (fun () ->
        let _ = Process.await server_proc in
        traceln "child process exited" ) ]
