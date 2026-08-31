open Motorsport_cli
open Harness
module Calendar = Motorsport_calendar
module Duration = Util_duration
module Hour_clock = Util_hour_clock
module Metadata = Motorsport_metadata
module Wec = Motorsport_wec

let contains substr s =
  let n = String.length substr and m = String.length s in
  let rec go i = i + n <= m && (String.sub s i n = substr || go (i + 1)) in
  n = 0 || go 0

(** The calendar entries these tests convert. Written out rather than looked up,
    so a change to the real calendar cannot quietly rewrite what a test is
    asserting about. *)
let le_mans : Calendar.entry = { entry_season = 2025; entry_id = "le_mans_24h"; entry_date = "2025-06-14" }

let fuji : Calendar.entry = { entry_season = 2025; entry_id = "fuji_6h"; entry_date = "2025-09-28" }

(** A round [Motorsport_events] has no name for. *)
let unlisted : Calendar.entry = { entry_season = 2025; entry_id = "custom_event"; entry_date = "2025-01-01" }

let mk_hour raw = match Hour_clock.parse raw with Ok h -> h | Error _ -> Hour_clock.Hour 0
let mk_duration raw = Duration.of_string raw |> Option.value ~default:Duration.zero

(** Builds a raw lap with only the columns a test needs filled in; of the 16, the
    rest are placeholders. *)
let mk_lap car_number lap_number elapsed driver_name class_ group team manufacturer : Wec.raw_lap =
  {
    car = { car_number; class_; group; team; manufacturer };
    driver = { number = 1; name = driver_name };
    lap_number;
    lap_time = Duration.of_millis 90000;
    lap_improvement = Wec.No_improvement;
    crossing_finish_line_in_pit = false;
    s1 = { value = None; improvement = Wec.No_improvement };
    s2 = { value = None; improvement = Wec.No_improvement };
    s3 = { value = None; improvement = Wec.No_improvement };
    kph = "0";
    elapsed = mk_duration elapsed;
    hour = Hour_clock.Hour 0;
    top_speed = "";
    pit_time = None;
    flag_at_fl = Wec.Green;
    mini_sectors = None;
  }

(** Gives a lap the S1 the grid is really ordered by; [mk_lap] leaves it blank. *)
let with_s1 s1 (lap : Wec.raw_lap) : Wec.raw_lap =
  { lap with s1 = { value = Duration.of_string s1; improvement = Wec.No_improvement } }

(** Gives a lap the time of day it crossed the line at; [mk_lap] leaves every lap
    at midnight, which would put every race's start at minus its elapsed. *)
let with_hour hour (lap : Wec.raw_lap) : Wec.raw_lap = { lap with hour = mk_hour hour }

let car_numbers (grid : Metadata.starting_grid) =
  List.map (fun (e : Metadata.starting_grid_entry) -> e.car.car_number) grid.entries

let suite =
  ( "Motorsport.TestMetadata",
    [
      ( "testEventDisplayNameApplied",
        fun () ->
          let laps = [ mk_lap "7" 1 "1:33.291" "KOBAYASHI" "HYPERCAR" "H" "Toyota" "Toyota" ] in
          let meta = Metadata.from_raw_laps le_mans laps in
          assert_true (meta.name = "24 Hours of Le Mans") );
      ( "testUnknownEventPassThrough",
        fun () ->
          let laps = [ mk_lap "7" 1 "1:33.291" "KOBAYASHI" "HYPERCAR" "H" "Toyota" "Toyota" ] in
          let meta = Metadata.from_raw_laps unlisted laps in
          assert_true (meta.name = "custom_event") );
      ( (* 12 leads on S1, but 7 was first to finish the lap. The CSV order
           (7, 12) does not survive either. *)
        "testGridOrderedByLap1S1NotElapsed",
        fun () ->
          let laps =
            [
              with_s1 "30.500" (mk_lap "7" 1 "1:33.291" "KOBAYASHI" "HYPERCAR" "H" "Toyota" "Toyota");
              with_s1 "29.100" (mk_lap "12" 1 "1:35.365" "STEVENS" "HYPERCAR" "H" "Hertz" "Porsche");
            ]
          in
          let grid = (Metadata.from_raw_laps le_mans laps).starting_grid in
          assert_true (grid.basis = Metadata.Lap1_s1);
          match grid.entries with
          | [ e12; e7 ] ->
            assert_true (e12.car.car_number = "12");
            assert_true (e12.position = 1);
            assert_true (e7.car.car_number = "7");
            assert_true (e7.position = 2)
          | _ -> assert_true false );
      ( (* A feed with no S1 is read by lap-1 elapsed, and basis says so. *)
        "testGridFallsBackToLap1Elapsed",
        fun () ->
          let laps =
            [
              mk_lap "12" 1 "1:35.365" "STEVENS" "HYPERCAR" "H" "Hertz" "Porsche";
              mk_lap "7" 1 "1:33.291" "KOBAYASHI" "HYPERCAR" "H" "Toyota" "Toyota";
            ]
          in
          let grid = (Metadata.from_raw_laps le_mans laps).starting_grid in
          assert_true (grid.basis = Metadata.Lap1_elapsed);
          match grid.entries with
          | [ e7; e12 ] ->
            assert_true (e7.car.car_number = "7");
            assert_true (e7.position = 1);
            assert_true (e12.car.car_number = "12");
            assert_true (e12.position = 2)
          | _ -> assert_true false );
      ( (* One car short of an S1 puts every readable car on elapsed. #7's S1
           (1:10) is under #12's elapsed (1:35), but the two are not compared. *)
        "testMixedFeedOrdersEveryoneByElapsed",
        fun () ->
          let laps =
            [
              with_s1 "1:10.000" (mk_lap "7" 1 "1:40.000" "KOBAYASHI" "HYPERCAR" "H" "Toyota" "Toyota");
              mk_lap "12" 1 "1:35.365" "STEVENS" "HYPERCAR" "H" "Hertz" "Porsche";
            ]
          in
          let grid = (Metadata.from_raw_laps le_mans laps).starting_grid in
          assert_true (grid.basis = Metadata.Lap1_elapsed);
          match grid.entries with
          | [ e12; e7 ] ->
            assert_true (e12.car.car_number = "12");
            assert_true (e12.position = 1);
            assert_true (e7.car.car_number = "7");
            assert_true (e7.position = 2)
          | _ -> assert_true false );
      ( (* #99 turned no first lap, so it has no say in the choice and does not
           take the other two cars' S1 down with it. *)
        "testUnreadableCarDoesNotCostTheFieldItsS1",
        fun () ->
          let laps =
            [
              with_s1 "30.500" (mk_lap "7" 1 "1:33.291" "KOBAYASHI" "HYPERCAR" "H" "Toyota" "Toyota");
              with_s1 "29.100" (mk_lap "12" 1 "1:35.365" "STEVENS" "HYPERCAR" "H" "Hertz" "Porsche");
              mk_lap "99" 2 "3:30.000" "X" "HYPERCAR" "H" "T" "M";
            ]
          in
          let grid = (Metadata.from_raw_laps le_mans laps).starting_grid in
          assert_true (grid.basis = Metadata.Lap1_s1);
          assert_true (car_numbers grid = [ "12"; "7"; "99" ]) );
      ( (* All three share an S1. 7 comes out on top on elapsed; 9 and 10 tie
           there too, so the car number settles it, as strings: "10" before "9". *)
        "testEqualS1BreaksOnElapsedThenCarNumber",
        fun () ->
          let laps =
            [
              with_s1 "29.100" (mk_lap "9" 1 "1:35.365" "X" "LMGT3" "G" "T" "M");
              with_s1 "29.100" (mk_lap "10" 1 "1:35.365" "STEVENS" "HYPERCAR" "H" "Hertz" "Porsche");
              with_s1 "29.100" (mk_lap "7" 1 "1:33.291" "KOBAYASHI" "HYPERCAR" "H" "Toyota" "Toyota");
            ]
          in
          let grid = (Metadata.from_raw_laps le_mans laps).starting_grid in
          assert_true (car_numbers grid = [ "7"; "10"; "9" ]) );
      ( "testDriversAccumulatedInCsvOrder",
        fun () ->
          let laps =
            [
              mk_lap "12" 1 "1:35.365" "STEVENS" "HYPERCAR" "H" "Hertz" "Porsche";
              mk_lap "12" 2 "3:07.610" "FRIJNS" "HYPERCAR" "H" "Hertz" "Porsche";
            ]
          in
          let meta = Metadata.from_raw_laps le_mans laps in
          match meta.starting_grid.entries with
          | [ entry ] -> assert_true (entry.car.drivers = [ "STEVENS"; "FRIJNS" ])
          | _ -> assert_true false );
      ( "testDriversDeduped",
        fun () ->
          let laps =
            [
              mk_lap "12" 1 "1:35.365" "STEVENS" "HYPERCAR" "H" "Hertz" "Porsche";
              mk_lap "12" 2 "3:07.610" "STEVENS" "HYPERCAR" "H" "Hertz" "Porsche";
              mk_lap "12" 3 "4:50.000" "FRIJNS" "HYPERCAR" "H" "Hertz" "Porsche";
            ]
          in
          let meta = Metadata.from_raw_laps le_mans laps in
          match meta.starting_grid.entries with
          | [ entry ] -> assert_true (entry.car.drivers = [ "STEVENS"; "FRIJNS" ])
          | _ -> assert_true false );
      ( "testCarMetaFromFirstLap",
        fun () ->
          let laps = [ mk_lap "7" 1 "1:33.291" "KOBAYASHI" "HYPERCAR" "H" "Toyota Gazoo Racing" "Toyota" ] in
          let meta = Metadata.from_raw_laps le_mans laps in
          match meta.starting_grid.entries with
          | [ entry ] ->
            assert_true (entry.car.class_ = "HYPERCAR");
            assert_true (entry.car.group = "H");
            assert_true (entry.car.team = "Toyota Gazoo Racing");
            assert_true (entry.car.manufacturer = "Toyota")
          | _ -> assert_true false );
      ( (* Placed at the back rather than dropped. Car number 1 sorts under 7 and
           still does not pass a car that could be read. *)
        "testCarWithoutLap1GoesToTheBack",
        fun () ->
          let laps =
            [
              mk_lap "1" 2 "3:30.000" "X" "HYPERCAR" "H" "T" "M";
              with_s1 "29.100" (mk_lap "7" 1 "1:33.291" "KOBAYASHI" "HYPERCAR" "H" "Toyota" "Toyota");
            ]
          in
          let meta = Metadata.from_raw_laps le_mans laps in
          match meta.starting_grid.entries with
          | [ e7; e1 ] ->
            assert_true (e7.car.car_number = "7");
            assert_true (e7.position = 1);
            assert_true (e1.car.car_number = "1");
            assert_true (e1.position = 2)
          | _ -> assert_true false );
      ( (* Positions still fill 1..n when no car can be read. *)
        "testGridWithoutAnyLap1IsUnknownButStillPlaced",
        fun () ->
          let laps =
            [ mk_lap "99" 2 "3:30.000" "X" "HYPERCAR" "H" "T" "M"; mk_lap "8" 2 "3:31.000" "Y" "HYPERCAR" "H" "T" "M" ]
          in
          let grid = (Metadata.from_raw_laps le_mans laps).starting_grid in
          assert_true (grid.basis = Metadata.Unknown);
          match grid.entries with
          | [ e8; e99 ] ->
            assert_true (e8.car.car_number = "8");
            assert_true (e8.position = 1);
            assert_true (e99.car.car_number = "99");
            assert_true (e99.position = 2)
          | _ -> assert_true false );
      ( (* The last car home did 2:30:00, so a two-hour race ran half an hour
           over -- which is the ordinary way a timed race ends, on the lap in
           progress when the flag falls. *)
        "testRaceRanAsFarAsTheLastLapTaken",
        fun () ->
          let laps =
            [
              mk_lap "7" 1 "1:33.291" "KOBAYASHI" "HYPERCAR" "H" "Toyota" "Toyota";
              mk_lap "12" 3 "2:30:00.000" "STEVENS" "HYPERCAR" "H" "Hertz" "Porsche";
              mk_lap "7" 2 "2:29:00.000" "KOBAYASHI" "HYPERCAR" "H" "Toyota" "Toyota";
            ]
          in
          let race = (Metadata.from_raw_laps fuji laps).race in
          assert_true (race.duration = mk_duration "2:30:00.000");
          assert_true (race.time_limit = mk_duration "2:00:00.000");
          assert_true (race.lap_total = 3) );
      ( (* Fuji 2025's opening lap: crossed the line at 11:02:32.086 having taken
           1:35.343 to get there. *)
        "testStartedAtIsHourLessElapsed",
        fun () ->
          let laps =
            [ with_hour "11:02:32.086" (mk_lap "7" 1 "1:35.343" "KOBAYASHI" "HYPERCAR" "H" "Toyota" "Toyota") ]
          in
          let race = (Metadata.from_raw_laps fuji laps).race in
          assert_true (race.started_at = Some (mk_hour "11:00:56.743")) );
      ( (* Le Mans starts at 16:00 and runs past midnight, so hour wraps while
           elapsed keeps growing: a lap done at 02:00 is ten hours in. *)
        "testStartedAtSurvivesMidnight",
        fun () ->
          let laps =
            [ with_hour "02:00:00.000" (mk_lap "7" 300 "10:00:00.000" "KOBAYASHI" "HYPERCAR" "H" "Toyota" "Toyota") ]
          in
          let race = (Metadata.from_raw_laps le_mans laps).race in
          assert_true (race.started_at = Some (mk_hour "16:00:00.000")) );
      ( "testNoLapsLeavesTheRaceUnread",
        fun () ->
          let race = (Metadata.from_raw_laps fuji []).race in
          assert_true (race.started_at = None);
          assert_true (race.duration = Duration.zero);
          assert_true (race.time_limit = Duration.zero);
          assert_true (race.lap_total = 0) );
      ( "testUnreadStartIsOmittedRatherThanMidnight",
        fun () ->
          let json = Util_json_encode.render (Metadata.to_json (Metadata.from_raw_laps fuji [])) in
          assert_true (not (contains "\"startedAt\"" json)) );
      ( (* The name still falls back to the id, because an entry can name a round
           Motorsport_events has never been told about. The date cannot fall back
           to anything, and does not have to: it came in with the entry. *)
        "testAnUnnamedRoundIsStillDated",
        fun () ->
          let laps = [ mk_lap "7" 1 "1:33.291" "KOBAYASHI" "HYPERCAR" "H" "Toyota" "Toyota" ] in
          let meta = Metadata.from_raw_laps unlisted laps in
          assert_true (meta.name = "custom_event");
          assert_true (meta.date = "2025-01-01") );
      ( "testToJsonRendersExpectedKeys",
        fun () ->
          let laps =
            [
              with_hour "16:01:33.291"
                (with_s1 "29.100" (mk_lap "7" 1 "1:33.291" "KOBAYASHI" "HYPERCAR" "H" "Toyota" "Toyota"));
            ]
          in
          let meta = Metadata.from_raw_laps le_mans laps in
          let json = Util_json_encode.render (Metadata.to_json meta) in
          (* Asserts the shape: that the keys are present. *)
          assert_true (contains "\"name\"" json);
          assert_true (contains "\"24 Hours of Le Mans\"" json);
          assert_true (contains "\"season\": 2025" json);
          assert_true (contains "\"date\": \"2025-06-14\"" json);
          assert_true (contains "\"race\"" json);
          assert_true (contains "\"startedAt\": \"16:00:00.000\"" json);
          assert_true (contains "\"duration\": \"1:33.291\"" json);
          assert_true (contains "\"timeLimit\": \"0.000\"" json);
          assert_true (contains "\"lapTotal\": 1" json);
          assert_true (contains "\"startingGrid\"" json);
          assert_true (contains "\"basis\": \"lap1_s1\"" json);
          assert_true (contains "\"entries\"" json);
          assert_true (contains "\"position\": 1" json);
          assert_true (contains "\"carNumber\"" json);
          assert_true (contains "\"drivers\"" json);
          assert_true (contains "\"name\": \"KOBAYASHI\"" json);
          assert_true (contains "\"manufacturer\": \"Toyota\"" json) );
    ] )
