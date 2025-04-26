open Ppx_yojson_conv_lib.Yojson_conv.Primitives
open! Import
module Json = Jsonrpc.Json

let current_version = "2025-03-26"

type error = Jsonrpc.Response.Error.t

exception Jsonrpc_error of Jsonrpc.Response.Error.t

exception Json_decoding_error of string

module type Extensible_key = sig
  type key

  val gen_key : key QCheck.Gen.t
  (** To be derived with ppx_deriving_qcheck *)

  val arb_key : key QCheck.arbitrary

  (* To be derived with ppx_deriving_show *)
  val pp_key : Format.formatter -> key -> unit

  val key_of_string : string -> key

  val string_of_key : key -> string
end

module type Jsonable2 = sig
  type t

  val yojson_of_t : t -> Json.t

  val t_of_yojson : Json.t -> t

  val pp : Format.formatter -> t -> unit
end

module type Properties = sig
  type key

  val gen_key : key QCheck.Gen.t

  val arb_key : key QCheck.arbitrary

  type value

  type t = (key * value) list

  val string_of_key : key -> string

  val key_of_string : string -> key

  val yojson_of_t : t -> Json.t

  val t_of_yojson : Json.t -> t

  val pp : Format.formatter -> t -> unit

  val show : t -> string
end

module Make_properties (Key : Extensible_key) (Value : Jsonable2) :
  Properties with type key = Key.key and type value := Value.t = struct
  type key = Key.key

  let gen_key = Key.gen_key

  let arb_key = Key.arb_key

  type value = Value.t

  let string_of_key = Key.string_of_key

  let key_of_string = Key.key_of_string

  let pp_key = Key.pp_key

  let pp_value = Value.pp

  type t = (key * value) list [@@deriving show]

  let t_of_yojson (y : Yojson.Safe.t) =
    match y with
    | `Assoc assoc ->
        List.map
          (fun (key, value) ->
            (Key.key_of_string key, Value.t_of_yojson value) )
          assoc
    | _ -> raise (Json_decoding_error "Must be assoc")

  let yojson_of_t assoc =
    `Assoc
      (List.map
         (fun (key, value) ->
           (Key.string_of_key key, Value.yojson_of_t value) )
         assoc )
end

module Capabilities = struct
  module Capability =
    Make_properties
      (struct
        type key = [`subscribe | `listChanged | `other of string]
        [@@deriving show, qcheck]

        let key_of_string = function
          | "subscribe" -> `subscribe
          | "listChanged" -> `listChanged
          | string -> `other string

        let string_of_key = function
          | `subscribe -> "subscribe"
          | `listChanged -> "listChanged"
          | `other string -> string
      end)
      (struct
        type t = bool [@@deriving show, yojson]
      end)

  module Client =
    Make_properties
      (struct
        type key = [`roots | `sampling | `experimental | `other of string]
        [@@deriving show, qcheck]

        let key_of_string = function
          | "roots" -> `roots
          | "sampling" -> `sampling
          | "experimental" -> `experimental
          | string -> `other string

        let string_of_key = function
          | `roots -> "roots"
          | `sampling -> "sampling"
          | `experimental -> "experimental"
          | `other string -> string
      end)
      (struct
        type t = Capability.t [@@deriving show, yojson]
      end)

  module Server =
    Make_properties
      (struct
        type key =
          [ `prompts
          | `resources
          | `tools
          | `logging
          | `experimental
          | `other of string ]
        [@@deriving show, qcheck]

        let key_of_string = function
          | "prompts" -> `prompts
          | "resources" -> `resources
          | "tools" -> `tools
          | "logging" -> `logging
          | "experimental" -> `experimental
          | string -> `other string

        let string_of_key = function
          | `prompts -> "prompts"
          | `resources -> "resources"
          | `tools -> "tools"
          | `logging -> "logging"
          | `experimental -> "experimental"
          | `other string -> string
      end)
      (struct
        type t = Capability.t [@@deriving show, yojson]
      end)
end

module type Peer_info = sig
  type t = {name: string; version: string}

  val yojson_of_t : t -> Json.t

  val t_of_yojson : Json.t -> t

  val pp : Format.formatter -> t -> unit

  val show : t -> string
end

module Client_info : Peer_info = struct
  type t = {name: string; version: string} [@@deriving yojson, show]
end

module Server_info : Peer_info = struct
  type t = {name: string; version: string} [@@deriving yojson, show]
end

(* Initialization phase *)
module Initialization = struct
  let method_ = "initialize"

  type params =
    {capabilities: Capabilities.Client.t; client_info: Client_info.t}

  let encode_params {capabilities; client_info} =
    `Assoc
      [ ("protocolVersion", `String current_version)
      ; ("capabilities", Capabilities.Client.yojson_of_t capabilities)
      ; ("clientInfo", Client_info.yojson_of_t client_info) ]

  type result =
    { protocol_version: string [@key "protocolVersion"]
    ; capabilities: Capabilities.Server.t
    ; server_info: Server_info.t [@key "serverInfo"] }
  [@@deriving yojson]
end

module Resource_list = struct
  let method_ = "resources/list"

  let cap = `resources

  type params_t = {cursor: string option [@default None]} [@@deriving yojson]

  type params = params_t option

  let encode_params =
    Option.map
    @@ function
    | {cursor} -> (
      match cursor with
      | Some cursor_string -> `Assoc [("cursor", `String cursor_string)]
      | None -> `Assoc [] )

  type item =
    { uri: string
    ; name: string
    ; description: string option
          [@default None] [@yojson_drop_default.yojson]
    ; mime_type: string option
          [@default None] [@key "mimeType"] [@yojson_drop_default.yojson]
    ; size: int option [@default None] [@yojson_drop_default.yojson] }
  [@@deriving yojson]

  type result =
    { resources: item list
    ; next_cursor: string option
          [@key "nextCursor"] [@default None] [@yojson_drop_default.yojson]
    }
  [@@deriving yojson]

  let decode_result = result_of_yojson
end
