open OUnit2

let suite = "Test ppx_protobuf" >::: [
    Test_wire.suite;
    Test_syntax.suite;
  ]

let _ =
  run_test_tt_main suite
