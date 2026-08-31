open Motorsport_cli
open Harness
module Decode = Util_csv_decode
module Duration = Util_duration
module Hour_clock = Util_hour_clock
module Mini_sector = Motorsport_mini_sector
module Wec = Motorsport_wec

let contains substr s =
  let n = String.length substr and m = String.length s in
  let rec go i = i + n <= m && (String.sub s i n = substr || go (i + 1)) in
  n = 0 || go 0

let header =
  "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS"

(** Le Mans header: base columns + 30 mini-sector columns
    ([<NAME>_time;<NAME>_elapsed] for each of the 15 markers in track order). *)
let le_mans_header =
  header
  ^ ";SCL2_time;SCL2_elapsed;Z4_time;Z4_elapsed;IP1_time;IP1_elapsed"
  ^ ";Z12_time;Z12_elapsed;SCLC_time;SCLC_elapsed;A7-1_time;A7-1_elapsed;IP2_time;IP2_elapsed"
  ^ ";A8-1_time;A8-1_elapsed;SCLB_time;SCLB_elapsed;PORIN_time;PORIN_elapsed;POROUT_time;POROUT_elapsed;PITREF_time;PITREF_elapsed;SCL1_time;SCL1_elapsed;FORDOUT_time;FORDOUT_elapsed;FL_time;FL_elapsed"

let decode_with head line =
  match Decode.decode_custom ~field_separator:';' Decode.Field_names_from_first_row (Wec.decoder ()) (head ^ "\n" ^ line) with
  | Ok (r :: _) -> Ok r
  | Ok [] -> Error (Decode.Decoding_errors [])
  | Error e -> Error e

(** Decodes a single semicolon-separated CSV line (without header) and pulls the
    first record out of the result. The header row is prepended automatically so
    the decoder can resolve field names. *)
let decode_one line = decode_with header line

(** Decode a single Le Mans-shaped row (base 29 fields + 30 mini-sector fields). *)
let decode_le_mans_one line = decode_with le_mans_header line

let sample_row =
  "12;1;3;2:41.963;0;;41.805;0;1:03.483;0;56.675;0;101.4;6:10.938;11:06:38.429;0:41.805;1:03.483;0:56.675;88.5;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;41.805;63.483;56.675;"

let row_with old_value new_value =
  let n = String.length old_value in
  let rec go i =
    if i + n > String.length sample_row then sample_row
    else if String.sub sample_row i n = old_value then
      String.sub sample_row 0 i ^ new_value ^ String.sub sample_row (i + n) (String.length sample_row - i - n)
    else go (i + 1)
  in
  go 0

(** Real first-lap row from app/static/wec/2025/le_mans_24h.csv (car 007 lap 1). *)
let real_le_mans_lap_row =
  "007;1;1;3:54.555;0;;51.908;0;1:23.252;0;1:39.395;0;206.9;3:54.555;16:03:54.555;0:51.908;1:23.252;1:39.395;328.8;Harry TINCKNELL;;HYPERCAR;;Aston Martin Thor Team;Aston Martin;GF;51.908;83.252;99.395;"
  ^ "20.708;20.708;13.826;34.534;17.374;51.908;"
  ^ "35.154;1:27.062;4.685;1:31.747;26.059;1:57.806;17.354;2:15.160;"
  ^ "6.928;2:22.088;37.644;2:59.732;17.155;3:16.887;16.786;3:33.673;7.954;3:41.627;2.885;3:44.512;6.560;3:51.072;3.483;3:54.555"

let suite =
  ( "Motorsport.TestWec",
    [
      ( "testFromCsvRowValid",
        fun () ->
          match decode_one sample_row with
          | Ok (r : Wec.raw_lap) ->
            assert_true (r.car.car_number = "12");
            assert_true (r.driver.number = 1);
            assert_true (r.lap_number = 3);
            assert_true (r.lap_time = Duration.of_millis 161963);
            assert_true (r.lap_improvement = Wec.No_improvement);
            assert_true (r.crossing_finish_line_in_pit = false);
            assert_true (r.s1.value = Some (Duration.of_millis 41805));
            assert_true (r.s1.improvement = Wec.No_improvement);
            assert_true (r.s2.value = Some (Duration.of_millis 63483));
            assert_true (r.s3.value = Some (Duration.of_millis 56675));
            assert_true (r.kph = "101.4");
            assert_true (r.elapsed = Duration.of_millis 370938);
            assert_true (r.hour = Hour_clock.Hour 39998429);
            assert_true (r.top_speed = "88.5");
            assert_true (r.driver.name = "Will STEVENS");
            assert_true (r.pit_time = None);
            assert_true (r.car.class_ = "HYPERCAR");
            assert_true (r.car.group = "H");
            assert_true (r.car.team = "Hertz Team JOTA");
            assert_true (r.car.manufacturer = "Porsche");
            assert_true (r.flag_at_fl = Wec.Slow_zone)
          | Error _ -> assert_true false );
      ( (* TOP_SPEED "150.0" is kept as-is (no .0 stripping). *)
        "testTopSpeedPreservedAsIs",
        fun () ->
          match decode_one (row_with ";88.5;Will STEVENS" ";150.0;Will STEVENS") with
          | Ok (r : Wec.raw_lap) -> assert_true (r.top_speed = "150.0")
          | Error _ -> assert_true false );
      ( (* KPH is rendered as a JSON string, preserving the CSV value. *)
        "testToJsonRendersKphAsString",
        fun () ->
          match decode_one (row_with ";101.4;" ";86.0;") with
          | Ok r ->
            let json = Util_json_encode.render (Wec.to_json r) in
            assert_true (contains "\"kph\": \"86.0\"" json)
          | Error _ -> assert_true false );
      ( "testToJsonGroupsLapAndSectors",
        fun () ->
          match decode_one sample_row with
          | Ok r ->
            let json = Util_json_encode.render (Wec.to_json r) in
            assert_true (contains "\"lap\": {" json);
            assert_true (contains "\"sectors\": {" json);
            assert_true (not (contains "\"lapImprovement\"" json));
            assert_true (not (contains "\"s1Improvement\"" json));
            assert_true (not (contains "\"driverNumber\"" json))
          | Error _ -> assert_true false );
      ( "testToJsonCarriesCarNumberAlone",
        fun () ->
          match decode_one sample_row with
          | Ok r ->
            let json = Util_json_encode.render (Wec.to_json r) in
            assert_true (contains "\"carNumber\": \"12\"" json);
            assert_true (not (contains "HYPERCAR" json));
            assert_true (not (contains "Hertz Team JOTA" json));
            assert_true (not (contains "Porsche" json))
          | Error _ -> assert_true false );
      ( (* PIT_TIME "0:01:41.031" is parsed to ms and re-rendered as "1:41.031"
           by the decoder + JSON encoder pipeline. *)
        "testFromCsvRowNormalizesPitTime",
        fun () ->
          match decode_one (row_with "Will STEVENS;;HYPERCAR" "Will STEVENS;0:01:41.031;HYPERCAR") with
          | Ok (r : Wec.raw_lap) -> assert_true (r.pit_time = Some (Duration.of_millis 101031))
          | Error _ -> assert_true false );
      ( (* Two well-formed rows decode into two records. *)
        "testFromCsvRowsAllValid",
        fun () ->
          let csv =
            header ^ "\n"
            ^ "12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;0:23.155;0:29.928;0:42.282;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;23.155;29.928;42.282;\n7;1;1;1:35.421;0;;23.277;0;29.848;0;42.296;0;160.5;1:35.421;11:02:02.912;0:23.277;0:29.848;0:42.296;;Kamui KOBAYASHI;;HYPERCAR;H;Toyota Gazoo Racing;Toyota;GF;23.277;29.848;42.296;"
          in
          match Decode.decode_custom ~field_separator:';' Decode.Field_names_from_first_row (Wec.decoder ()) csv with
          | Ok records -> assert_true (List.length records = 2)
          | Error _ -> assert_true false );
      ( (* TOP_SPEED blank -- common on non-pit laps. The empty string
           round-trips to JSON unchanged. *)
        "testFromCsvRowEmptyTopSpeed",
        fun () ->
          match decode_one (row_with ";88.5;Will STEVENS" ";;Will STEVENS") with
          | Ok (r : Wec.raw_lap) -> assert_true (r.top_speed = "")
          | Error _ -> assert_true false );
      ( (* KPH that parses as no kind of number fails decode. *)
        "testUnparseableKphFailsDecode",
        fun () ->
          match decode_one (row_with ";101.4;" ";not-a-number;") with
          | Ok _ -> assert_true false
          | Error _ -> assert_true true );
      ( "testBlankLapTimeFailsDecode",
        fun () ->
          match decode_one (row_with "12;1;3;2:41.963;" "12;1;3;;") with
          | Ok _ -> assert_true false
          | Error _ -> assert_true true );
      ( "testUnparseableHourFailsDecode",
        fun () ->
          match decode_one (row_with ";11:06:38.429;" ";garbage;") with
          | Ok _ -> assert_true false
          | Error _ -> assert_true true );
      ( (* The standard WEC header has no mini-sector columns, so decode should
           succeed with mini_sectors = None and to_json must omit the
           miniSectors key entirely. *)
        "testNonLeMansCsvLeavesMiniSectorsNone",
        fun () ->
          match decode_one sample_row with
          | Ok (r : Wec.raw_lap) ->
            assert_true (r.mini_sectors = None);
            let json = Util_json_encode.render (Wec.to_json r) in
            assert_true (not (contains "miniSectors" json))
          | Error _ -> assert_true false );
      ( "testLeMansRowDecodesAllFifteenMiniSectors",
        fun () ->
          match decode_le_mans_one real_le_mans_lap_row with
          | Ok (r : Wec.raw_lap) -> (
            match r.mini_sectors with
            | None -> assert_true false
            | Some list ->
              assert_true (List.length list = 15);
              (* First entry must be SCL2 with time = 20.708 (= 20708 ms). *)
              (match list with
              | (id, (sector : Wec.raw_mini_sector)) :: _ ->
                assert_true (id = Mini_sector.SCL2);
                assert_true (sector.time = Some (Duration.of_millis 20708));
                assert_true (sector.mini_elapsed = Some (Duration.of_millis 20708))
              | [] -> assert_true false);
              (* Last entry must be FL with elapsed = lapTime (3:54.555 = 234555 ms). *)
              (match List.rev list with
              | (id, (sector : Wec.raw_mini_sector)) :: _ ->
                assert_true (id = Mini_sector.FL);
                assert_true (sector.mini_elapsed = Some (Duration.of_millis 234555))
              | [] -> assert_true false))
          | Error _ -> assert_true false );
      ( (* Confirm A7-1 / A8-1 round-trip to a7_1 / a8_1 in the JSON output
           (matches Motorsport.Lap.MiniSectors field names on the Elm side). *)
        "testLeMansRowJsonContainsMiniSectorsWithHyphenedKeys",
        fun () ->
          match decode_le_mans_one real_le_mans_lap_row with
          | Ok r ->
            let json = Util_json_encode.render (Wec.to_json r) in
            assert_true (contains "\"miniSectors\"" json);
            assert_true (contains "\"a7_1\"" json);
            assert_true (contains "\"a8_1\"" json);
            assert_true (not (contains "\"a7-1\"" json));
            assert_true (contains "\"scl2\"" json);
            assert_true (contains "\"fl\"" json)
          | Error _ -> assert_true false );
      ( (* When every mini-sector column in a Le Mans row is blank, the whole
           mini_sectors field collapses to None and the JSON omits the key. *)
        "testLeMansRowAllBlankMiniSectorsCollapseToNone",
        fun () ->
          let blanks = ";;;;;;;;;;;;;;;;;;;;;;;;;;;;;;" in
          let line =
            "007;1;1;3:54.555;0;;51.908;0;1:23.252;0;1:39.395;0;206.9;3:54.555;16:03:54.555;0:51.908;1:23.252;1:39.395;328.8;Harry TINCKNELL;;HYPERCAR;;Aston Martin Thor Team;Aston Martin;GF;51.908;83.252;99.395"
            ^ blanks
          in
          match decode_le_mans_one line with
          | Ok (r : Wec.raw_lap) ->
            assert_true (r.mini_sectors = None);
            let json = Util_json_encode.render (Wec.to_json r) in
            assert_true (not (contains "miniSectors" json))
          | Error _ -> assert_true false );
    ] )
