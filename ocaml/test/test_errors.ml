open Motorsport_cli
open Harness

let contains substr s =
  let n = String.length substr and m = String.length s in
  let rec go i = i + n <= m && (String.sub s i n = substr || go (i + 1)) in
  n = 0 || go 0

let suite =
  ( "Cli.TestErrors",
    [
      ( "testPathNotFoundRendersPath",
        fun () ->
          let s = Cli_errors.to_string (Cli_errors.Input_path_not_found "/tmp/missing.csv") in
          assert_true (contains "Path not found" s);
          assert_true (contains "/tmp/missing.csv" s) );
      ( "testCsvErrorPreservesPathAndCause",
        fun () ->
          let s = Cli_errors.to_string (Cli_errors.Csv { path = "/tmp/race.csv"; message = "Field S1 missing on row 7" }) in
          assert_true (contains "/tmp/race.csv" s);
          assert_true (contains "caused by:" s);
          assert_true (contains "Field S1 missing on row 7" s) );
      ( "testFileErrorDelegatesToFileErrorToString",
        fun () ->
          let inner = Util_files.Read_error ("/tmp/x.csv", "permission denied") in
          let s = Cli_errors.to_string (Cli_errors.File inner) in
          assert_true (s = "Failed to read /tmp/x.csv (caused by: permission denied)") );
    ] )
