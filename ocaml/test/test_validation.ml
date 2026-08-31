open Motorsport_cli
open Harness
module Decode = Util_csv_decode
module Duration = Util_duration
module Mini_sector = Motorsport_mini_sector
module Validation = Cli_stages_validation
module Wec = Motorsport_wec

let contains substr s =
  let n = String.length substr and m = String.length s in
  let rec go i = i + n <= m && (String.sub s i n = substr || go (i + 1)) in
  n = 0 || go 0

let replace old_value new_value s =
  let n = String.length old_value in
  let rec go i =
    if i + n > String.length s then s
    else if String.sub s i n = old_value then
      String.sub s 0 i ^ new_value ^ String.sub s (i + n) (String.length s - i - n)
    else go (i + 1)
  in
  go 0

let header =
  "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS"

let le_mans_header =
  header
  ^ ";SCL2_time;SCL2_elapsed;Z4_time;Z4_elapsed;IP1_time;IP1_elapsed"
  ^ ";Z12_time;Z12_elapsed;SCLC_time;SCLC_elapsed;A7-1_time;A7-1_elapsed;IP2_time;IP2_elapsed"
  ^ ";A8-1_time;A8-1_elapsed;SCLB_time;SCLB_elapsed;PORIN_time;PORIN_elapsed;POROUT_time;POROUT_elapsed;PITREF_time;PITREF_elapsed;SCL1_time;SCL1_elapsed;FORDOUT_time;FORDOUT_elapsed;FL_time;FL_elapsed"

let decode_one head row =
  match Decode.decode_custom ~field_separator:';' Decode.Field_names_from_first_row (Wec.decoder ()) (head ^ "\n" ^ row) with
  | Ok (r :: _) -> r
  | _ -> unreachable ()

let build_lap num lap lap_time s1 s2 s3 elapsed hour =
  let row =
    Printf.sprintf "%s;1;%d;%s;0;;%s;0;%s;0;%s;0;100;%s;%s;0:%s;0:%s;0:%s;200;Driver;;HYPERCAR;H;Team;Maker;GF;%s;%s;%s;"
      num lap lap_time s1 s2 s3 elapsed hour s1 s2 s3 s1 s2 s3
  in
  decode_one header row

(** Le Mans lap builder with explicit values for the CROSSING_FINISH_LINE_IN_PIT
    and PIT_TIME columns. Pass [box = "B"] to mark the lap as a pit-entry lap, or
    [pit_time = "30.500"] to record a pit-stop duration. *)
let build_le_mans_lap_with num lap lap_time s1 s2 s3 elapsed hour mini_tail box pit_time =
  let row =
    Printf.sprintf
      "%s;1;%d;%s;0;%s;%s;0;%s;0;%s;0;100;%s;%s;0:%s;0:%s;0:%s;200;Driver;%s;HYPERCAR;H;Team;Maker;GF;%s;%s;%s;%s" num
      lap lap_time box s1 s2 s3 elapsed hour s1 s2 s3 pit_time s1 s2 s3 mini_tail
  in
  decode_one le_mans_header row

(** Build a Le Mans-shaped lap. [mini_tail] is the raw 30-column suffix
    ([time;elapsed;...]) appended after the standard fields.

    Note: [s3] must be a plain-seconds string (e.g. ["64.000"], not
    ["1:04.000"]) because the Le Mans CSV has trailing [S3_SECONDS]-style columns
    that go through the float parser. Real Le Mans S3 values run 1:30+, so this
    fixture is intentionally simplified -- the integrity rules under test don't
    care about realistic lap geometry, only the arithmetic relationships between
    the columns. *)
let build_le_mans_lap num lap lap_time s1 s2 s3 elapsed hour mini_tail =
  build_le_mans_lap_with num lap lap_time s1 s2 s3 elapsed hour mini_tail "" ""

(** 15 sub-sectors that cleanly split the 2:00.000 lap into 8000 ms each. The
    [_elapsed] column is the running total at each marker. *)
let clean_mini_tail =
  "8.000;8.000;8.000;16.000;8.000;24.000" ^ ";8.000;32.000;8.000;40.000;8.000;48.000;8.000;56.000"
  ^ ";8.000;1:04.000;8.000;1:12.000;8.000;1:20.000;8.000;1:28.000;8.000;1:36.000;8.000;1:44.000;8.000;1:52.000;8.000;2:00.000"

(** 15 sub-sectors with the trailing FORDOUT and FL_time blanked out -- the
    canonical "pit-entry lap" pattern observed in real Le Mans data (the car
    skips the main-line FORDOUT loop and crosses FL inside the pit lane). The
    FL_elapsed value is preserved at lapTime so the lap itself is still completed
    at the finish line. *)
let pit_entry_mini_tail =
  "8.000;8.000;8.000;16.000;8.000;24.000" ^ ";8.000;32.000;8.000;40.000;8.000;48.000;8.000;56.000"
  ^ ";8.000;1:04.000;8.000;1:12.000;8.000;1:20.000;8.000;1:28.000;8.000;1:36.000;8.000;1:44.000;;;;2:00.000"

(** Track-limits violation at the second Ford chicane: SCL1 + FORDOUT loops not
    triggered. FL_elapsed is preserved at lapTime since the car still crosses the
    finish line. The on-track markers retain their straight-line cumulative
    times. *)
let track_limits_scl1_fordout_mini_tail =
  "8.000;8.000;8.000;16.000;8.000;24.000" ^ ";8.000;32.000;8.000;40.000;8.000;48.000;8.000;56.000"
  ^ ";8.000;1:04.000;8.000;1:12.000;8.000;1:20.000;8.000;1:28.000;8.000;1:36.000;;;;;8.000;2:00.000"

(** Track-limits violation at the first Ford chicane: PITREF + SCL1 loops not
    triggered. The car re-joins the main racing line before FORDOUT, so FORDOUT
    and FL fire normally. *)
let track_limits_pitref_scl1_mini_tail =
  "8.000;8.000;8.000;16.000;8.000;24.000" ^ ";8.000;32.000;8.000;40.000;8.000;48.000;8.000;56.000"
  ^ ";8.000;1:04.000;8.000;1:12.000;8.000;1:20.000;8.000;1:28.000;;;;;8.000;1:52.000;8.000;2:00.000"

(** Pulls the car number off the leading lap argument shared by every variant. *)
let violation_car (v : Validation.violation) =
  match v with
  | Sector_sum (lap, _, _, _) -> lap.Wec.car.Wec.car_number
  | Elapsed_drift (lap, _, _) -> lap.Wec.car.Wec.car_number
  | Hour_elapsed_offset (lap, _, _) -> lap.Wec.car.Wec.car_number
  | Mini_sector_sum (lap, _, _, _) -> lap.Wec.car.Wec.car_number
  | Mini_sector_elapsed_monotonic (lap, _, _, _, _) -> lap.Wec.car.Wec.car_number

let is_sector_sum (v : Validation.violation) = match v with Sector_sum _ -> true | _ -> false
let is_elapsed_drift (v : Validation.violation) = match v with Elapsed_drift _ -> true | _ -> false
let is_hour_elapsed_offset (v : Validation.violation) = match v with Hour_elapsed_offset _ -> true | _ -> false
let is_mini_sector_sum (v : Validation.violation) = match v with Mini_sector_sum _ -> true | _ -> false

let is_mini_sector_monotonic (v : Validation.violation) =
  match v with Mini_sector_elapsed_monotonic _ -> true | _ -> false

let suite =
  ( "Cli.Stages.TestValidation",
    [
      ( "testValidLapsProduceNoViolations",
        fun () ->
          let l1 = build_lap "7" 1 "2:00.000" "30.000" "60.000" "30.000" "2:00.000" "14:02:00.000" in
          let l2 = build_lap "7" 2 "2:00.000" "30.000" "60.000" "30.000" "4:00.000" "14:04:00.000" in
          assert_true (Validation.detect [ l1; l2 ] = []) );
      ( (* s1+s2+s3 = 30.000+60.000+30.001 = 2:00.001, lapTime = 2:00.000 -> 1ms
           diff. elapsed and hour are aligned with lapTime so SectorSum is the
           only violation. *)
        "testSectorSumMismatchDetected",
        fun () ->
          let lap = build_lap "7" 1 "2:00.000" "30.000" "60.000" "30.001" "2:00.000" "14:02:00.000" in
          let violations = Validation.detect [ lap ] in
          assert_true (List.length violations = 1);
          match violations with
          | [ Validation.Sector_sum (_, lap_ms, sum, _) ] ->
            assert_true (lap_ms = Duration.of_millis 120000);
            assert_true (sum = Duration.of_millis 120001)
          | _ -> assert_true false );
      ( "testElapsedDriftMismatchDetected",
        fun () ->
          let l1 = build_lap "7" 1 "2:00.000" "30.000" "60.000" "30.000" "2:00.000" "14:02:00.000" in
          (* lap2 elapsed should be 4:00.000 but is 4:00.500 *)
          let l2 = build_lap "7" 2 "2:00.000" "30.000" "60.000" "30.000" "4:00.500" "14:04:00.500" in
          assert_true (List.exists is_elapsed_drift (Validation.detect [ l1; l2 ])) );
      ( (* Cumulative-sum: when lap 2 drifts by 500ms, lap 3 is "consistent
           relative to lap 2" (an adjacent-diff check would clear it) but still
           disagrees with the running sum, so it must be reported too. This
           mirrors the Rust implementation's behaviour. *)
        "testElapsedDriftCumulativeReportsTrailingLaps",
        fun () ->
          let l1 = build_lap "7" 1 "2:00.000" "30.000" "60.000" "30.000" "2:00.000" "14:02:00.000" in
          let l2 = build_lap "7" 2 "2:00.000" "30.000" "60.000" "30.000" "4:00.500" "14:04:00.500" in
          let l3 = build_lap "7" 3 "2:00.000" "30.000" "60.000" "30.000" "6:00.500" "14:06:00.500" in
          let violations = Validation.detect [ l1; l2; l3 ] |> List.filter is_elapsed_drift in
          assert_true (List.length violations = 2);
          (* 1st: lap 2, expected=4:00.000 (running sum), actual=4:00.500
             2nd: lap 3, expected=6:00.000 (running sum), actual=6:00.500 *)
          match violations with
          | [ Validation.Elapsed_drift (lap1, exp1, act1); Validation.Elapsed_drift (lap2, exp2, act2) ] ->
            assert_true (lap1.Wec.lap_number = 2);
            assert_true (exp1 = Duration.of_millis 240000);
            assert_true (act1 = Duration.of_millis 240500);
            assert_true (lap2.Wec.lap_number = 3);
            assert_true (exp2 = Duration.of_millis 360000);
            assert_true (act2 = Duration.of_millis 360500)
          | _ -> assert_true false );
      ( (* baseline (race-wide first valid row) = 14:02:00.000 - 2:00.000 =
           13:58:00.000; lap 2 offset = 14:04:00.500 - 4:00.000 = 13:58:00.500
           (off by 500ms vs baseline) *)
        "testHourElapsedMismatchDetected",
        fun () ->
          let l1 = build_lap "7" 1 "2:00.000" "30.000" "60.000" "30.000" "2:00.000" "14:02:00.000" in
          let l2 = build_lap "7" 2 "2:00.000" "30.000" "60.000" "30.000" "4:00.000" "14:04:00.500" in
          let violations = Validation.detect [ l1; l2 ] |> List.filter is_hour_elapsed_offset in
          assert_true (List.length violations = 1) );
      ( (* race starts near midnight: lap1 hour=23:59:00.000, lap2
           hour=00:01:00.000 (next day) *)
        "testMidnightWrapAccepted",
        fun () ->
          let l1 = build_lap "7" 1 "1:00.000" "20.000" "20.000" "20.000" "1:00.000" "23:59:00.000" in
          let l2 = build_lap "7" 2 "2:00.000" "30.000" "60.000" "30.000" "3:00.000" "0:01:00.000" in
          let violations = Validation.detect [ l1; l2 ] |> List.filter is_hour_elapsed_offset in
          assert_true (violations = []) );
      ( (* empty s2: sum = 30+0+30 = 1:00.000, lapTime = 2:00.000 -> violation
           with blanks = ["s2"] *)
        "testBlankSectorTreatedAsZeroAndAnnotated",
        fun () ->
          let lap = build_lap "7" 1 "2:00.000" "30.000" "" "30.000" "2:00.000" "14:02:00.000" in
          let violations = Validation.detect [ lap ] |> List.filter is_sector_sum in
          assert_true (List.length violations = 1);
          match violations with
          | [ Validation.Sector_sum (_, _, _, blanks) ] -> assert_true (List.mem "s2" blanks)
          | _ -> assert_true false );
      ( (* car 7 ok, car 8 has elapsed mismatch on lap 2 *)
        "testMultipleCarsGroupedSeparately",
        fun () ->
          let c7l1 = build_lap "7" 1 "2:00.000" "30.000" "60.000" "30.000" "2:00.000" "14:02:00.000" in
          let c7l2 = build_lap "7" 2 "2:00.000" "30.000" "60.000" "30.000" "4:00.000" "14:04:00.000" in
          let c8l1 = build_lap "8" 1 "2:00.000" "30.000" "60.000" "30.000" "2:00.000" "14:02:00.000" in
          let c8l2 = build_lap "8" 2 "2:00.000" "30.000" "60.000" "30.000" "4:00.500" "14:04:00.500" in
          let violations = Validation.detect [ c7l1; c7l2; c8l1; c8l2 ] in
          assert_true (List.filter (fun v -> violation_car v = "7") violations = []);
          assert_true (List.filter (fun v -> violation_car v = "8") violations <> []) );
      ( (* The race-wide baseline is taken from the first valid row in the whole
           CSV, so even if car "8" lap 1's hour is 1 ms off, car "7" lap 1 anchors
           the baseline and only car "8" lap 1 is flagged (car "8" lap 2 is
           consistent and therefore clean). *)
        "testRaceWideBaselineIsolatesBadFirstLap",
        fun () ->
          let c7l1 = build_lap "7" 1 "2:00.000" "30.000" "60.000" "30.000" "2:00.000" "14:02:00.000" in
          let c8l1 = build_lap "8" 1 "2:00.000" "30.000" "60.000" "30.000" "2:00.000" "14:02:00.001" in
          let c8l2 = build_lap "8" 2 "2:00.000" "30.000" "60.000" "30.000" "4:00.000" "14:04:00.000" in
          let violations = Validation.detect [ c7l1; c8l1; c8l2 ] |> List.filter is_hour_elapsed_offset in
          assert_true (List.length violations = 1);
          match violations with
          | [ Validation.Hour_elapsed_offset (lap, _, _) ] ->
            assert_true (lap.Wec.car.Wec.car_number = "8");
            assert_true (lap.Wec.lap_number = 1)
          | _ -> assert_true false );
      ( (* car "10" appears before car "7" in the CSV; violations should come
           back in that same order. (A map orders by key, so "10" < "7"
           lexically -- without an explicit sort the report would be reversed.) *)
        "testCsvOrderPreservedInReport",
        fun () ->
          let c10l1 = build_lap "10" 1 "2:00.000" "30.000" "60.000" "30.000" "2:00.000" "14:02:00.000" in
          let c10l2 = build_lap "10" 2 "2:00.000" "30.000" "60.000" "30.000" "4:00.001" "14:04:00.001" in
          let c7l1 = build_lap "7" 1 "2:00.000" "30.000" "60.000" "30.000" "2:00.000" "14:02:00.000" in
          let c7l2 = build_lap "7" 2 "2:00.000" "30.000" "60.000" "30.000" "4:00.001" "14:04:00.001" in
          let violations = Validation.detect [ c10l1; c10l2; c7l1; c7l2 ] |> List.filter is_elapsed_drift in
          assert_true (List.length violations = 2);
          match violations with
          | [ v1; v2 ] ->
            assert_true (violation_car v1 = "10");
            assert_true (violation_car v2 = "7")
          | _ -> assert_true false );
      ( (* Standard (non-Le Mans) header -> mini_sectors = None -> mini-sector
           checks must be skipped entirely. *)
        "testMiniSectorsAbsentLapProducesNoMiniViolations",
        fun () ->
          let lap = build_lap "7" 1 "2:00.000" "30.000" "60.000" "30.000" "2:00.000" "14:02:00.000" in
          let violations = Validation.detect [ lap ] in
          assert_true (List.filter is_mini_sector_sum violations = []);
          assert_true (List.filter is_mini_sector_monotonic violations = []) );
      ( "testValidLeMansLapProducesNoMiniViolations",
        fun () ->
          let lap =
            build_le_mans_lap "7" 1 "2:00.000" "24.000" "32.000" "64.000" "2:00.000" "14:02:00.000" clean_mini_tail
          in
          assert_true (Validation.detect [ lap ] = []) );
      ( (* Bump the FL_time from 8.000 -> 8.001, leaving lapTime 2:00.000 -> sum
           = 2:00.001, off by 1 ms. Note this also breaks the FL_elapsed
           monotonic chain so we filter to the sum-style violation. *)
        "testMiniSectorSumMismatchDetected",
        fun () ->
          let bad_tail = replace "8.000;2:00.000" "8.001;2:00.000" clean_mini_tail in
          let lap =
            build_le_mans_lap "7" 1 "2:00.000" "24.000" "32.000" "64.000" "2:00.000" "14:02:00.000" bad_tail
          in
          let violations = Validation.detect [ lap ] |> List.filter is_mini_sector_sum in
          assert_true (List.length violations = 1);
          match violations with
          | [ Validation.Mini_sector_sum (_, lap_ms, sum, _) ] ->
            assert_true (lap_ms = Duration.of_millis 120000);
            assert_true (sum = Duration.of_millis 120001)
          | _ -> assert_true false );
      ( (* Blank Z4_time -> counted as 0 ms in the sum (8 + 0 + 8 + ... =
           1:52.000), so we expect a sum violation with Z4 in the blanks list. *)
        "testMiniSectorBlankTimeAnnotated",
        fun () ->
          let bad_tail = replace "8.000;8.000;8.000;16.000" "8.000;8.000;;16.000" clean_mini_tail in
          let lap =
            build_le_mans_lap "7" 1 "2:00.000" "24.000" "32.000" "64.000" "2:00.000" "14:02:00.000" bad_tail
          in
          let violations = Validation.detect [ lap ] |> List.filter is_mini_sector_sum in
          assert_true (List.length violations = 1);
          match violations with
          | [ Validation.Mini_sector_sum (_, _, _, blanks) ] -> assert_true (List.mem Mini_sector.Z4 blanks)
          | _ -> assert_true false );
      ( (* Replace IP1_elapsed (24.000) with 15.000 -- strictly less than the
           previous Z4_elapsed (16.000) -- to trigger a backwards step. *)
        "testMiniSectorElapsedMonotonicViolationDetected",
        fun () ->
          let bad_tail = replace "16.000;8.000;24.000" "16.000;8.000;15.000" clean_mini_tail in
          let lap =
            build_le_mans_lap "7" 1 "2:00.000" "24.000" "32.000" "64.000" "2:00.000" "14:02:00.000" bad_tail
          in
          let violations = Validation.detect [ lap ] |> List.filter is_mini_sector_monotonic in
          assert_true (List.length violations = 1);
          match violations with
          | [ Validation.Mini_sector_elapsed_monotonic (_, prev_id, prev_elapsed, curr_id, curr_elapsed) ] ->
            assert_true (prev_id = Mini_sector.Z4);
            assert_true (curr_id = Mini_sector.IP1);
            assert_true (prev_elapsed = Duration.of_millis 16000);
            assert_true (curr_elapsed = Duration.of_millis 15000)
          | _ -> assert_true false );
      ( (* Two adjacent timing loops cannot physically fire at the same
           millisecond. Replace IP1_elapsed (24.000) with 16.000 so it matches
           the previous Z4_elapsed exactly -- the strict monotonic check should
           report this as a violation. *)
        "testMiniSectorElapsedEqualPairFlagged",
        fun () ->
          let bad_tail = replace "16.000;8.000;24.000" "16.000;8.000;16.000" clean_mini_tail in
          let lap =
            build_le_mans_lap "7" 1 "2:00.000" "24.000" "32.000" "64.000" "2:00.000" "14:02:00.000" bad_tail
          in
          let violations = Validation.detect [ lap ] |> List.filter is_mini_sector_monotonic in
          assert_true (List.length violations = 1);
          match violations with
          | [ Validation.Mini_sector_elapsed_monotonic (_, prev_id, prev_elapsed, curr_id, curr_elapsed) ] ->
            assert_true (prev_id = Mini_sector.Z4);
            assert_true (curr_id = Mini_sector.IP1);
            assert_true (prev_elapsed = curr_elapsed);
            assert_true (prev_elapsed = Duration.of_millis 16000)
          | _ -> assert_true false );
      ( (* Real pit-entry pattern: car crosses FL inside the pit lane
           (CROSSING_FINISH_LINE_IN_PIT = "B"), bypasses FORDOUT and the FL_time
           loop. Sum of mini-sector times = 1:44.000 << lapTime = 2:00.000, but
           we expect NO sum violation because the lap is identified as a pit
           lap. *)
        "testMiniSectorSumSkippedOnBoxedFinishLineLap",
        fun () ->
          let lap =
            build_le_mans_lap_with "7" 1 "2:00.000" "24.000" "32.000" "64.000" "2:00.000" "14:02:00.000"
              pit_entry_mini_tail "B" ""
          in
          assert_true (Validation.detect [ lap ] |> List.filter is_mini_sector_sum = []) );
      ( (* Even without the boxed-finish-line flag, a recorded PIT_TIME also
           marks the lap as a pit lap and skips the sum check. *)
        "testMiniSectorSumSkippedWhenPitTimeRecorded",
        fun () ->
          let lap =
            build_le_mans_lap_with "7" 1 "2:00.000" "24.000" "32.000" "64.000" "2:00.000" "14:02:00.000"
              pit_entry_mini_tail "" "30.500"
          in
          assert_true (Validation.detect [ lap ] |> List.filter is_mini_sector_sum = []) );
      ( (* {fordout, fl} blank without any pit or track-limits signal -- a genuine
           timing anomaly (e.g. Le Mans 2025 car 150 lap 14: 4:23.067 lap with
           FORDOUT and FL_time both blank, no pitTime, no box flag, no
           track-limits signature). The validator must STILL flag this. *)
        "testMiniSectorSumStillReportsNonPitLapWithBlankTrailingMarkers",
        fun () ->
          let lap =
            build_le_mans_lap_with "150" 14 "2:00.000" "24.000" "32.000" "64.000" "2:00.000" "14:02:00.000"
              pit_entry_mini_tail "" ""
          in
          assert_true (List.length (Validation.detect [ lap ] |> List.filter is_mini_sector_sum) = 1) );
      ( (* Track-limits violation at the second Ford chicane: SCL1 and FORDOUT
           loops are not triggered. No pit signal. *)
        "testMiniSectorSumSkippedOnScl1FordoutTrackLimits",
        fun () ->
          let lap =
            build_le_mans_lap_with "7" 1 "2:00.000" "24.000" "32.000" "64.000" "2:00.000" "14:02:00.000"
              track_limits_scl1_fordout_mini_tail "" ""
          in
          assert_true (Validation.detect [ lap ] |> List.filter is_mini_sector_sum = []) );
      ( (* Track-limits violation at the first Ford chicane: PITREF and SCL1 loops
           are not triggered, but the car rejoins before FORDOUT so FORDOUT and
           FL fire normally. *)
        "testMiniSectorSumSkippedOnPitrefScl1TrackLimits",
        fun () ->
          let lap =
            build_le_mans_lap_with "7" 1 "2:00.000" "24.000" "32.000" "64.000" "2:00.000" "14:02:00.000"
              track_limits_pitref_scl1_mini_tail "" ""
          in
          assert_true (Validation.detect [ lap ] |> List.filter is_mini_sector_sum = []) );
      ( (* The monotonic check is independent of pit context: missing markers
           don't break monotonicity (blank elapsed is skipped), but a backwards
           step must still be reported even when the lap is a pit lap. *)
        "testMiniSectorMonotonicStillRunsOnPitLaps",
        fun () ->
          let bad_tail = replace "16.000;8.000;24.000" "16.000;8.000;15.000" pit_entry_mini_tail in
          let lap =
            build_le_mans_lap_with "7" 1 "2:00.000" "24.000" "32.000" "64.000" "2:00.000" "14:02:00.000" bad_tail "B"
              ""
          in
          let violations = Validation.detect [ lap ] in
          assert_true (List.filter is_mini_sector_sum violations = []);
          assert_true (List.length (List.filter is_mini_sector_monotonic violations) = 1) );
      ( (* Format: "sector-sum" slug + "expected=...ms... actual=...ms...".
           elapsed and hour are aligned with lapTime so the formatted output is
           validated solely against the sector-sum case. *)
        "testValidateRendersFormattedString",
        fun () ->
          let lap = build_lap "7" 1 "2:00.000" "30.000" "60.000" "30.001" "2:00.000" "14:02:00.000" in
          let messages = Validation.validate "test" [ lap ] in
          assert_true (List.length messages = 1);
          match messages with
          | [ msg ] ->
            assert_true (contains "sector-sum" msg);
            assert_true (contains "[car 7 #1]" msg);
            assert_true (contains "expected=2:00.000 (120000ms)" msg);
            assert_true (contains "actual=2:00.001 (120001ms)" msg)
          | _ -> assert_true false );
    ] )
