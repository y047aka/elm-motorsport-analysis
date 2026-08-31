open Motorsport_cli
open Harness
open Util_json_encode

let contains substr s =
  let n = String.length substr and m = String.length s in
  let rec go i = i + n <= m && (String.sub s i n = substr || go (i + 1)) in
  n = 0 || go 0

let suite =
  ( "Util.TestJson",
    [
      ("testRenderNull", fun () -> assert_true (render Json_null = "null"));
      ("testRenderBoolTrue", fun () -> assert_true (render (Json_bool true) = "true"));
      ("testRenderBoolFalse", fun () -> assert_true (render (Json_bool false) = "false"));
      ("testRenderInt", fun () -> assert_true (render (Json_int 42) = "42"));
      ("testRenderString", fun () -> assert_true (render (Json_string "hello") = "\"hello\""));
      ( "testRenderStringWithQuotes",
        fun () ->
          let result = render (Json_string "say \"hi\"") in
          assert_true (contains "\\\"" result) );
      ("testRenderEmptyArray", fun () -> assert_true (render (Json_array []) = "[]"));
      ("testRenderEmptyObject", fun () -> assert_true (render (Json_object []) = "{}"));
      ( "testRenderObject",
        fun () ->
          let obj = Json_object [ ("name", Json_string "test"); ("value", Json_int 1) ] in
          let result = render obj in
          assert_true (contains "\"name\": \"test\"" result);
          assert_true (contains "\"value\": 1" result) );
      ( "testRenderArray",
        fun () ->
          let arr = Json_array [ Json_int 1; Json_int 2 ] in
          let result = render arr in
          assert_true (contains "1" result);
          assert_true (contains "2" result) );
    ] )
