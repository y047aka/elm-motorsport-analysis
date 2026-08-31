open Motorsport_cli
open Harness
module Calendar = Motorsport_calendar
module Events = Motorsport_events
module Direction = Motorsport_circuit_direction

let suite =
  ( "Motorsport.TestEvents",
    [
      ("testQatar", fun () -> assert_true (Events.display_name "qatar_1812km" = "Qatar 1812km"));
      ("testImola", fun () -> assert_true (Events.display_name "imola_6h" = "6 Hours of Imola"));
      ("testSpa", fun () -> assert_true (Events.display_name "spa_6h" = "6 Hours of Spa"));
      ("testLeMans", fun () -> assert_true (Events.display_name "le_mans_24h" = "24 Hours of Le Mans"));
      ("testCota", fun () -> assert_true (Events.display_name "cota_6h" = "Lone Star Le Mans"));
      ("testFuji", fun () -> assert_true (Events.display_name "fuji_6h" = "6 Hours of Fuji"));
      ("testBahrain", fun () -> assert_true (Events.display_name "bahrain_8h" = "8 Hours of Bahrain"));
      ( "testSaoPaulo",
        fun () -> assert_true (Events.display_name "sao_paulo_6h" = "6 Hours of S\xc3\xa3o Paulo") );
      ("testUnknownPassThrough", fun () -> assert_true (Events.display_name "unknown_event" = "unknown_event"));
      ( (* Reads the ids off Motorsport_calendar rather than listing them again,
           so a round added to the calendar and to nothing else fails here. *)
        "testEveryRoundOnTheCalendarHasADirection",
        fun () ->
          let ids =
            [ 2024; 2025; 2026 ]
            |> List.concat_map (fun season -> Calendar.rounds season |> Option.value ~default:[])
            |> List.map (fun (r : Calendar.round) -> r.id)
          in
          assert_true (ids <> []);
          assert_true (List.for_all (fun id -> Events.direction id <> None) ids);
          assert_true (List.for_all (fun id -> Events.display_name id <> id) ids) );
      ( "testWhichRoundsRunCounterClockwise",
        fun () ->
          assert_true (Events.direction "imola_6h" = Some Direction.Counter_clockwise);
          assert_true (Events.direction "cota_6h" = Some Direction.Counter_clockwise);
          assert_true (Events.direction "sao_paulo_6h" = Some Direction.Counter_clockwise);
          assert_true (Events.direction "fuji_6h" = Some Direction.Clockwise) );
      ("testUnknownRoundHasNoDirection", fun () -> assert_true (Events.direction "unknown_event" = None));
    ] )
