open Motorsport_cli
open Harness
module Csv_input = Cli_stages_csv_input

let suite =
  ( "Cli.Stages.TestCsvInput",
    [
      ( (* The other half of the calendar's two-way check: a round is listed and
           its CSV was never filed. *)
        "testAListedRoundWithNoCsvFailsAsMissing",
        fun () ->
          match Csv_input.read "../app/static/wec/2025/monza_6h.csv" with
          | Error (Cli_errors.Input_path_not_found p) -> assert_true (p = "../app/static/wec/2025/monza_6h.csv")
          | _ -> assert_true false );
    ] )
