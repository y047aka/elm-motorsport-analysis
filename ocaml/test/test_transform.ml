open Motorsport_cli
open Harness
module Calendar = Motorsport_calendar
module Decode = Util_csv_decode
module Transform = Cli_stages_transform
module Wec = Motorsport_wec

let contains substr s =
  let n = String.length substr and m = String.length s in
  let rec go i = i + n <= m && (String.sub s i n = substr || go (i + 1)) in
  n = 0 || go 0

let starts_with prefix s = String.length s >= String.length prefix && String.sub s 0 (String.length prefix) = prefix

let ends_with suffix s =
  String.length s >= String.length suffix
  && String.sub s (String.length s - String.length suffix) (String.length suffix) = suffix

let le_mans : Calendar.entry = { entry_season = 2025; entry_id = "le_mans_24h"; entry_date = "2025-06-14" }

let header =
  "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS"

(** The three rows Rust's create_test_csv_data uses (integration.rs L500-505):
    semicolon-separated, 22 columns or more. *)
let sample_raw_laps () =
  let csv =
    header ^ "\n"
    ^ "12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:00.000;;;;310.5;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;;;\n"
    ^ "7;1;1;1:33.291;0;;23.119;0;29.188;0;40.984;0;175.0;1:33.291;11:02:00.000;;;;298.6;Kamui KOBAYASHI;;HYPERCAR;H;Toyota Gazoo Racing;Toyota;GF;;;\n"
    ^ "12;2;2;1:32.245;1;;22.500;1;29.100;1;40.645;1;165.2;3:07.610;11:03:32.000;;;;312.0;Robin FRIJNS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;;;"
  in
  match Decode.decode_custom ~field_separator:';' Decode.Field_names_from_first_row (Wec.decoder ()) csv with
  | Ok rs -> rs
  | Error _ -> unreachable ()

let suite =
  ( "Cli.Stages.TestTransform",
    [
      ( "testTransformCountsLaps",
        fun () ->
          let out = Transform.transform le_mans (sample_raw_laps ()) in
          assert_true (out.lap_count = 3) );
      ( "testTransformRendersMetadataJson",
        fun () ->
          let out = Transform.transform le_mans (sample_raw_laps ()) in
          let json = out.metadata_json in
          assert_true (contains "\"24 Hours of Le Mans\"" json);
          assert_true (contains "\"startingGrid\"" json);
          assert_true (contains "\"carNumber\": \"7\"" json);
          assert_true (contains "\"carNumber\": \"12\"" json) );
      ( "testTransformRendersLapsJsonl",
        fun () ->
          let out = Transform.transform le_mans (sample_raw_laps ()) in
          let jsonl = out.laps_jsonl in
          assert_true (contains "\"lapNumber\": 1" jsonl);
          assert_true (contains "\"driverName\": \"Will STEVENS\"" jsonl);
          assert_true (contains "\"driverName\": \"Kamui KOBAYASHI\"" jsonl);
          assert_true (contains "\"driverName\": \"Robin FRIJNS\"" jsonl) );
      ( "testEveryLapIsOneLine",
        fun () ->
          let out = Transform.transform le_mans (sample_raw_laps ()) in
          let lines = String.split_on_char '\n' out.laps_jsonl |> List.filter (fun line -> line <> "") in
          assert_true (ends_with "\n" out.laps_jsonl);
          assert_true (List.length lines = 3);
          assert_true (List.for_all (fun line -> starts_with "{ " line && ends_with " }" line) lines) );
      ( "testTransformEmptyInputProducesNoLaps",
        fun () ->
          let out = Transform.transform le_mans [] in
          assert_true (out.lap_count = 0);
          assert_true (contains "\"basis\": \"unknown\"" out.metadata_json);
          assert_true (contains "\"entries\": []" out.metadata_json);
          assert_true (out.laps_jsonl = "") );
    ] )
