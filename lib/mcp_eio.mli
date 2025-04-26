(** An eio-based MCP client. *)
module Client : sig
  type _ Effect.t +=
    | Insufficient_server_capability : string -> 'a Effect.t
    | Invalid_response_schema : 'a Effect.t

  module Connection : sig
    type t

    val from_stdio :
         stdin:Eio_unix.sink_ty Eio.Std.r
      -> stdout:Eio_unix.source_ty Eio.Std.r
      -> t

    val read_response : t -> Jsonrpc.Response.t

    val send_request : t -> Jsonrpc.Request.t -> unit

    val notify : t -> Jsonrpc.Notification.t -> unit
  end

  type t

  val initialize : params:Mcp.Initialization.params -> Connection.t -> t

  val close : t -> unit

  val resource_list :
    params:Mcp.Resource_list.params -> t -> Mcp.Resource_list.result
end
