open Motorsport_cli
open Harness
module Args = Cli_args

let suite =
  ( "Cli.TestArgs",
    [
      ("testParseNoArgs", fun () -> assert_true (Result.is_error (Args.parse [])));
      ( "testParseRoot",
        fun () ->
          match Args.parse [ "../app/static/wec" ] with
          | Ok parsed -> assert_true (parsed.root = "../app/static/wec")
          | Error _ -> assert_true false );
      ( "testParseUnexpectedArgument",
        fun () -> assert_true (Result.is_error (Args.parse [ "../app/static/wec"; "extra" ])) );
      ( (* The calendar decides what is converted, so there is no single file to
           redirect. *)
        "testOutputIsNoLongerAnOption",
        fun () -> assert_true (Result.is_error (Args.parse [ "../app/static/wec"; "--output"; "out.json" ])) );
    ] )
