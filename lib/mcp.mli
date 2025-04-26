module Json = Jsonrpc.Json

val current_version : string
(** [current_version] is the latest version of the MCP specification supported
by this library. *)

type error = Jsonrpc.Response.Error.t

(** Raised when there is an error with the JSON-RPC protocol. *)
exception Jsonrpc_error of Jsonrpc.Response.Error.t

(** Raised when there is an error decoding a JSON value. *)
exception Json_decoding_error of string

(** Type for an extensible list of properties for MCP.

While the MCP specification
https://modelcontextprotocol.io/specification/2025-03-26/basic/lifecycle defines
key capabilities, it also allows non-standard capabilities and subcapabilities.

This module type defines a generic interface to such an object.
 *)
module type Properties = sig
  (** The type of keys in the properties. *)
  type key

  val gen_key : key QCheck.Gen.t

  val arb_key : key QCheck.arbitrary

  (** The type of values in the properties. *)
  type value

  val string_of_key : key -> string

  val key_of_string : string -> key

  (** The type of a list of key-value pairs. *)
  type t = (key * value) list

  val yojson_of_t : t -> Json.t

  val t_of_yojson : Json.t -> t

  val pp : Format.formatter -> t -> unit

  val show : t -> string
end

module Capabilities : sig
  (** A single capability with zero or more subcapabilities. *)
  module Capability :
    Properties
      with type key := [`subscribe | `listChanged | `other of string]
       and type value := bool

  (** Client capabilities. *)
  module Client :
    Properties
      with type key := [`roots | `sampling | `experimental | `other of string]
       and type value := Capability.t

  (** Server capabilities. *)
  module Server :
    Properties
      with type key :=
        [ `prompts
        | `resources
        | `tools
        | `logging
        | `experimental
        | `other of string ]
       and type value := Capability.t
end

(** [Peer_info] describes a connection peer (i.e. server or client). *)
module type Peer_info = sig
  type t = {name: string; version: string}

  val yojson_of_t : t -> Json.t

  val t_of_yojson : Json.t -> t

  val pp : Format.formatter -> t -> unit

  val show : t -> string
end

(** Client information sent from the client to the server during initialization. *)
module Client_info : Peer_info

(** Server information sent from the server to the client during initialization. *)
module Server_info : Peer_info

(** Initialization phase. *)
module Initialization : sig
  val method_ : string
  (** The method name for requests. *)

  (** Request parameters. *)
  type params =
    {capabilities: Capabilities.Client.t; client_info: Client_info.t}

  val encode_params : params -> Jsonrpc.Structured.t

  type result =
    { protocol_version: string
    ; capabilities: Capabilities.Server.t
    ; server_info: Server_info.t }

  val result_of_yojson : Yojson.Safe.t -> result
  (** Decodes the result of initialization from a JSON value. *)
end

(** Resource list. *)
module Resource_list : sig
  val method_ : string
  (** The method name for listing resources. *)

  val cap : [> `resources]
  (** The capability required for listing resources. *)

  (** The type of parameters for listing resources. *)
  type params_t = {cursor: string option}

  (** The type of parameters for listing resources, which may be absent. *)
  type params = params_t option

  val encode_params : params -> Jsonrpc.Structured.t option
  (** Encodes the parameters for listing resources. *)

  (** The type of an item in the resource list. *)
  type item =
    { uri: string
    ; name: string
    ; description: string option
    ; mime_type: string option
    ; size: int option }

  (** The type of the result of listing resources. *)
  type result = {resources: item list; next_cursor: string option}

  val decode_result : Jsonrpc.Json.t -> result
  (** Decodes the result of listing resources from a JSON value. *)
end
