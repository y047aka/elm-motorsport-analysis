open Motorsport_cli
open Harness
module Direction = Motorsport_circuit_direction
module Duration = Util_duration
module Hour_clock = Util_hour_clock
module Mini_sector = Motorsport_mini_sector
module Sector = Motorsport_sector
module Track = Motorsport_track
module Wec = Motorsport_wec

let contains substr s =
  let n = String.length substr and m = String.length s in
  let rec go i = i + n <= m && (String.sub s i n = substr || go (i + 1)) in
  n = 0 || go 0

let mk_sector ms : Wec.raw_sector = { value = Option.map Duration.of_millis ms; improvement = Wec.No_improvement }

(** A lap with only the columns the track's proportions are read from; of the 16,
    the rest are placeholders. *)
let mk_lap lap_time s1 s2 s3 : Wec.raw_lap =
  {
    car = { car_number = "7"; class_ = "HYPERCAR"; group = "H"; team = "Toyota"; manufacturer = "Toyota" };
    driver = { number = 1; name = "KOBAYASHI" };
    lap_number = 1;
    lap_time = Duration.of_millis lap_time;
    lap_improvement = Wec.No_improvement;
    crossing_finish_line_in_pit = false;
    s1 = mk_sector s1;
    s2 = mk_sector s2;
    s3 = mk_sector s3;
    kph = "0";
    elapsed = Duration.of_millis lap_time;
    hour = Hour_clock.Hour 0;
    top_speed = "";
    pit_time = None;
    flag_at_fl = Wec.Green;
    mini_sectors = None;
  }

let with_mini_sectors time_of (lap : Wec.raw_lap) : Wec.raw_lap =
  let entries =
    Mini_sector.all
    |> List.map (fun id ->
           (id, ({ time = Option.map Duration.of_millis (time_of id); mini_elapsed = None } : Wec.raw_mini_sector)))
  in
  { lap with mini_sectors = Some entries }

(** Gives every mini-sector the same time, which makes a sector's share of the
    lap its count of mini-sectors -- 3, 4 and 8 of the 15. *)
let with_even_mini_sectors each lap = with_mini_sectors (fun _ -> Some each) lap

let share_of sector (track : Track.t) =
  track.sectors |> List.find_opt (fun (other, _) -> other = sector) |> Option.map snd

let mini_share_of id (track : Track.t) =
  Option.bind track.mini_sectors (fun list -> List.find_opt (fun (other, _) -> other = id) list) |> Option.map snd

let close_to expected actual = Float.abs (expected -. actual) < 0.000001

let is_share start share (actual : Track.share option) =
  match actual with None -> false | Some s -> close_to start s.start && close_to share s.share

let suite =
  ( "Motorsport.TestTrack",
    [
      ( (* 20 + 30 + 50 of a 100-second lap. *)
        "testSectorTakesTheShareItsRecordIsOfTheLap",
        fun () ->
          let laps = [ mk_lap 100000 (Some 20000) (Some 30000) (Some 50000) ] in
          let track = Track.from_raw_laps (Some Direction.Clockwise) laps in
          assert_true (is_share 0.0 0.2 (share_of Sector.S1 track));
          assert_true (is_share 0.2 0.3 (share_of Sector.S2 track));
          assert_true (is_share 0.5 0.5 (share_of Sector.S3 track)) );
      ( "testRecordIsTheQuickestOfEveryLapNotTheFirst",
        fun () ->
          let laps =
            [
              mk_lap 200000 (Some 80000) (Some 60000) (Some 60000);
              mk_lap 100000 (Some 20000) (Some 30000) (Some 50000);
            ]
          in
          let track = Track.from_raw_laps (Some Direction.Clockwise) laps in
          assert_true (is_share 0.0 0.2 (share_of Sector.S1 track)) );
      ( (* S2 was never recorded, so S3 starts where S1 left off and the lap is
           still divided in full. *)
        "testStretchWithNoTimeTakesNoShare",
        fun () ->
          let laps = [ mk_lap 50000 (Some 20000) None (Some 30000) ] in
          let track = Track.from_raw_laps (Some Direction.Clockwise) laps in
          assert_true (is_share 0.0 0.4 (share_of Sector.S1 track));
          assert_true (is_share 0.4 0.0 (share_of Sector.S2 track));
          assert_true (is_share 0.4 0.6 (share_of Sector.S3 track)) );
      ( (* Nothing is known about how long each stretch is until a lap has been
           round, whether the file holds a blank lap or no laps at all. *)
        "testNoRecordsAtAllDividesTheLapEvenly",
        fun () ->
          [ [ mk_lap 0 None None None ]; [] ]
          |> List.iter (fun laps ->
                 let track = Track.from_raw_laps None laps in
                 assert_true (is_share 0.0 (1.0 /. 3.0) (share_of Sector.S1 track));
                 assert_true (is_share (2.0 /. 3.0) (1.0 /. 3.0) (share_of Sector.S3 track));
                 assert_true (track.mini_sectors = None)) );
      ( (* Fifteen equal mini-sectors, grouped 3 / 4 / 8. The sectors' own
           columns say something else entirely and are not consulted. *)
        "testSectorIsWhatItsMiniSectorsTakeBetweenThem",
        fun () ->
          let laps = [ with_even_mini_sectors 1000 (mk_lap 15000 (Some 1000) (Some 1000) (Some 1000)) ] in
          let track = Track.from_raw_laps (Some Direction.Clockwise) laps in
          assert_true (is_share 0.0 (3.0 /. 15.0) (share_of Sector.S1 track));
          assert_true (is_share (3.0 /. 15.0) (4.0 /. 15.0) (share_of Sector.S2 track));
          assert_true (is_share (7.0 /. 15.0) (8.0 /. 15.0) (share_of Sector.S3 track));
          assert_true (is_share 0.0 (1.0 /. 15.0) (mini_share_of Mini_sector.SCL2 track));
          assert_true (is_share (14.0 /. 15.0) (1.0 /. 15.0) (mini_share_of Mini_sector.FL track)) );
      ( (* The first lap has no lap time -- the feed writes 0.000 -- so its
           impossibly quick SCL2 does not take the record from the second. *)
        "testMiniSectorsOfALapWithNoLapTimeAreNotRecords",
        fun () ->
          let laps =
            [
              with_mini_sectors
                (fun id -> if id = Mini_sector.SCL2 then Some 1 else Some 1000)
                (mk_lap 0 None None None);
              with_even_mini_sectors 1000 (mk_lap 15000 None None None);
            ]
          in
          let track = Track.from_raw_laps (Some Direction.Clockwise) laps in
          assert_true (is_share 0.0 (1.0 /. 15.0) (mini_share_of Mini_sector.SCL2 track)) );
      ( "testOneRoundWithMiniSectorsPutsEveryLapAtThatGrain",
        fun () ->
          let laps =
            [
              mk_lap 15000 (Some 1000) (Some 1000) (Some 1000);
              with_even_mini_sectors 1000 (mk_lap 15000 (Some 1000) (Some 1000) (Some 1000));
            ]
          in
          let track = Track.from_raw_laps (Some Direction.Clockwise) laps in
          assert_true (is_share 0.0 (3.0 /. 15.0) (share_of Sector.S1 track)) );
      ( "testToJsonRendersExpectedKeys",
        fun () ->
          let laps = [ with_even_mini_sectors 1000 (mk_lap 15000 (Some 1000) (Some 1000) (Some 1000)) ] in
          let json =
            Util_json_encode.render (Track.to_json (Track.from_raw_laps (Some Direction.Clockwise) laps))
          in
          assert_true (contains "\"sectors\"" json);
          assert_true (contains "\"s1\"" json);
          assert_true (contains "\"start\"" json);
          assert_true (contains "\"share\"" json);
          assert_true (contains "\"miniSectors\"" json);
          assert_true (contains "\"scl2\"" json);
          assert_true (contains "\"fl\"" json) );
      ( "testDirectionIsWrittenOutAsGiven",
        fun () ->
          let laps = [ mk_lap 100000 (Some 20000) (Some 30000) (Some 50000) ] in
          let json =
            Util_json_encode.render (Track.to_json (Track.from_raw_laps (Some Direction.Counter_clockwise) laps))
          in
          assert_true (contains "\"direction\": \"counter_clockwise\"" json) );
      ( "testCircuitOfUnknownDirectionSaysNothing",
        fun () ->
          let laps = [ mk_lap 100000 (Some 20000) (Some 30000) (Some 50000) ] in
          let json = Util_json_encode.render (Track.to_json (Track.from_raw_laps None laps)) in
          assert_true (not (contains "\"direction\"" json)) );
      ( "testRoundWithoutMiniSectorsOmitsThem",
        fun () ->
          let laps = [ mk_lap 100000 (Some 20000) (Some 30000) (Some 50000) ] in
          let json =
            Util_json_encode.render (Track.to_json (Track.from_raw_laps (Some Direction.Clockwise) laps))
          in
          assert_true (not (contains "\"miniSectors\"" json)) );
    ] )
