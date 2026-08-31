open Motorsport_cli
open Harness
module Csv_decode = Cli_stages_csv_decode

let header =
  "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS"

let sample_row =
  "12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:00.000;;;;310.5;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;;;"

let suite =
  ( "Cli.Stages.TestCsvDecode",
    [
      ( "testDecodeParsesValidCsv",
        fun () ->
          let csv = header ^ "\n" ^ sample_row in
          match Csv_decode.decode "test.csv" csv with
          | Ok laps -> assert_true (List.length laps = 1)
          | Error _ -> assert_true false );
      ( "testDecodeStripsBom",
        fun () ->
          let csv = "\xef\xbb\xbf" ^ header ^ "\n" ^ sample_row in
          match Csv_decode.decode "test.csv" csv with
          | Ok laps -> assert_true (List.length laps = 1)
          | Error _ -> assert_true false );
      ( "testDecodeAttachesPathOnError",
        fun () ->
          let broken =
            header ^ "\n"
            ^ "12;not-a-number;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:00.000;;;;310.5;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;;;"
          in
          match Csv_decode.decode "/tmp/race.csv" broken with
          | Ok _ -> assert_true false
          | Error (Cli_errors.Csv r) -> assert_true (r.path = "/tmp/race.csv")
          | Error _ -> assert_true false );
    ] )
