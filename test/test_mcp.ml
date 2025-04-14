let subcapability_key =
  let open Mcp_example.Mcp.Capabilities.Capability in
  QCheck.Test.make ~count:100
    ~name:"Capabilities.Capability.key parsing and serialization (roundtrip)"
    (QCheck.make gen_key) (fun k -> key_of_string (string_of_key k) = k )

let client_capability_key =
  let open Mcp_example.Mcp.Capabilities.Client in
  QCheck.Test.make ~count:100
    ~name:"Capabilities.Client.key parsing and serialization (roundtrip)"
    (QCheck.make gen_key) (fun k -> key_of_string (string_of_key k) = k )

let server_capability_key =
  let open Mcp_example.Mcp.Capabilities.Server in
  QCheck.Test.make ~count:100
    ~name:"Capabilities.Server.key parsing and serialization (roundtrip)"
    (QCheck.make gen_key) (fun k -> key_of_string (string_of_key k) = k )

let () =
  let map_to_alcotest = List.map QCheck_alcotest.to_alcotest in
  let ser_roundtrip_tests =
    map_to_alcotest
      [subcapability_key; client_capability_key; server_capability_key]
  in
  Alcotest.run "Mcp" [("Serialization", ser_roundtrip_tests)]
