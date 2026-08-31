open Motorsport_cli
open Harness
open Util_json_encode
module Extra = Util_json_encode_extra

let show s = s

let suite =
  ( "Util.Json.TestEncodeExtra",
    [
      ("testRenderScalar", fun () -> assert_true (Extra.render (Json_string "hello") = "\"hello\""));
      ("testRenderEmptyObject", fun () -> assert_true (Extra.render (Json_object []) = "{}"));
      ( "testSinglePropertyObjectIsInline",
        fun () ->
          let obj = Json_object [ ("name", Json_string "James CALADO") ] in
          assert_eq ~show ~expected:"{ \"name\": \"James CALADO\" }" (Extra.render obj) );
      ( "testSinglePropertyObjectWithNullIsInline",
        fun () -> assert_eq ~show ~expected:"{ \"value\": null }" (Extra.render (Json_object [ ("value", Json_null) ])) );
      ( "testSinglePropertyObjectWithEmptyArrayIsInline",
        fun () ->
          assert_eq ~show ~expected:"{ \"drivers\": [] }" (Extra.render (Json_object [ ("drivers", Json_array []) ])) );
      ( "testNestedSinglePropertyObjectsCollapseTogether",
        fun () ->
          let obj = Json_object [ ("car", Json_object [ ("number", Json_string "7") ]) ] in
          assert_eq ~show ~expected:"{ \"car\": { \"number\": \"7\" } }" (Extra.render obj) );
      ( "testSinglePropertyObjectWithMultiLineValueIsNotInline",
        fun () ->
          let obj = Json_object [ ("drivers", Json_array [ Json_string "a"; Json_string "b" ]) ] in
          assert_eq ~show ~expected:"{\n  \"drivers\": [\n    \"a\",\n    \"b\"\n  ]\n}" (Extra.render obj) );
      ( "testTwoPropertyObjectIsInline",
        fun () ->
          let obj = Json_object [ ("time", Json_string "20.708"); ("elapsed", Json_string "20.708") ] in
          assert_eq ~show ~expected:"{ \"time\": \"20.708\", \"elapsed\": \"20.708\" }" (Extra.render obj) );
      ( "testTwoPropertyObjectWithOneMultiLineValueIsNotInline",
        fun () ->
          let obj = Json_object [ ("name", Json_string "test"); ("laps", Json_array [ Json_int 1; Json_int 2 ]) ] in
          assert_eq ~show ~expected:"{\n  \"name\": \"test\",\n  \"laps\": [\n    1,\n    2\n  ]\n}" (Extra.render obj) );
      ( "testThreePropertyObjectIsNotInline",
        fun () ->
          let obj =
            Json_object
              [ ("s1", Json_string "51.908"); ("s2", Json_string "1:23.252"); ("s3", Json_string "1:39.395") ]
          in
          assert_eq ~show
            ~expected:"{\n  \"s1\": \"51.908\",\n  \"s2\": \"1:23.252\",\n  \"s3\": \"1:39.395\"\n}"
            (Extra.render obj) );
      ( "testInlineObjectKeepsItsIndentInsideAnArray",
        fun () ->
          let arr = Json_array [ Json_object [ ("name", Json_string "Alex LYNN") ] ] in
          assert_eq ~show ~expected:"[\n  { \"name\": \"Alex LYNN\" }\n]" (Extra.render arr) );
      ( "testInlineObjectKeepsItsIndentAsAProperty",
        fun () ->
          let pair time elapsed = Json_object [ ("time", Json_string time); ("elapsed", Json_string elapsed) ] in
          let obj =
            Json_object
              [
                ("scl2", pair "20.708" "20.708"); ("z4", pair "13.826" "34.534"); ("ip1", pair "17.374" "51.908");
              ]
          in
          assert_eq ~show
            ~expected:
              (String.concat "\n"
                 [
                   "{";
                   "  \"scl2\": { \"time\": \"20.708\", \"elapsed\": \"20.708\" },";
                   "  \"z4\": { \"time\": \"13.826\", \"elapsed\": \"34.534\" },";
                   "  \"ip1\": { \"time\": \"17.374\", \"elapsed\": \"51.908\" }";
                   "}";
                 ])
            (Extra.render obj) );
      ( "testKeyIsEscaped",
        fun () ->
          let obj = Json_object [ ("say \"hi\"", Json_int 1) ] in
          assert_eq ~show ~expected:"{ \"say \\\"hi\\\"\": 1 }" (Extra.render obj) );
      ( "testOnOneLineKeepsAWideObjectOnOneLine",
        fun () ->
          let obj =
            Json_object
              [
                ("carNumber", Json_string "007");
                ("driverName", Json_string "Harry TINCKNELL");
                ("lapNumber", Json_int 1);
                ("elapsed", Json_string "1:42.619");
              ]
          in
          assert_eq ~show
            ~expected:
              "{ \"carNumber\": \"007\", \"driverName\": \"Harry TINCKNELL\", \"lapNumber\": 1, \"elapsed\": \"1:42.619\" }"
            (Extra.render_on_one_line obj) );
      ( "testOnOneLineFlattensNestedValues",
        fun () ->
          let pair time elapsed = Json_object [ ("time", Json_string time); ("elapsed", Json_string elapsed) ] in
          let obj =
            Json_object
              [
                ("miniSectors", Json_object [ ("scl2", pair "20.708" "20.708"); ("z4", pair "13.826" "34.534") ]);
                ("laps", Json_array [ Json_int 1; Json_int 2 ]);
              ]
          in
          assert_eq ~show
            ~expected:
              "{ \"miniSectors\": { \"scl2\": { \"time\": \"20.708\", \"elapsed\": \"20.708\" }, \"z4\": { \"time\": \"13.826\", \"elapsed\": \"34.534\" } }, \"laps\": [1, 2] }"
            (Extra.render_on_one_line obj) );
      ( "testOnOneLineNeverEmitsANewline",
        fun () ->
          let obj =
            Json_object
              [
                ("a", Json_array [ Json_object [ ("b", Json_int 1); ("c", Json_int 2); ("d", Json_int 3) ] ]);
                ("e", Json_object []);
                ("f", Json_array []);
              ]
          in
          assert_true (not (String.contains (Extra.render_on_one_line obj) '\n')) );
      ( "testOnOneLineRendersScalarsAsEncodeDoes",
        fun () ->
          assert_true (Extra.render_on_one_line (Json_string "say \"hi\"") = render (Json_string "say \"hi\"")) );
      ( "testExpandedObjectMatchesEncode",
        fun () ->
          let obj =
            Json_object
              [ ("name", Json_string "test"); ("season", Json_int 2025); ("laps", Json_array [ Json_int 1; Json_int 2 ]) ]
          in
          assert_true (Extra.render obj = render obj) );
    ] )
