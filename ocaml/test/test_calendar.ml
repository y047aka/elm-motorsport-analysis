open Motorsport_cli
open Harness
module Calendar = Motorsport_calendar

let starts_with prefix s = String.length s >= String.length prefix && String.sub s 0 (String.length prefix) = prefix

let suite =
  ( "Motorsport.TestCalendar",
    [
      ( "testASeasonNobodyHasFiledIsNotAnEmptyOne",
        fun () ->
          assert_true (Calendar.rounds 2019 = None);
          assert_true (Calendar.rounds 2027 = None) );
      ( "testARoundIsDatedWithinTheSeasonItBelongsTo",
        fun () ->
          assert_true (Calendar.find 2025 "spa_6h" |> Option.map (fun e -> e.Calendar.entry_date) = Some "2025-05-10");
          assert_true (Calendar.find 2026 "spa_6h" |> Option.map (fun e -> e.Calendar.entry_date) = Some "2026-05-09")
      );
      ( (* The season is half of a round's name. Neither half identifies it
           alone, which is why the entries carry both: 2024 ran no round at
           Imola. *)
        "testARoundASeasonDidNotRunIsNotAnEntry",
        fun () ->
          assert_true (Calendar.find 2024 "imola_6h" = None);
          assert_true (Calendar.find 2025 "unknown_event" = None);
          assert_true (Calendar.find 2019 "spa_6h" = None) );
      ( (* Stands in for the type the dates do not have. A round filed under the
           wrong season reads as a date, and only the year gives it away. *)
        "testEveryDateIsIsoAndCarriesItsOwnSeason",
        fun () ->
          assert_true
            (List.for_all
               (fun season ->
                 Calendar.rounds season |> Option.value ~default:[]
                 |> List.for_all (fun (r : Calendar.round) ->
                        String.length r.date = 10 && starts_with (string_of_int season ^ "-") r.date))
               [ 2024; 2025; 2026 ]) );
      ( (* The latest season is the first one listed and nothing else, so this is
           the whole of what the index page reads to put its badge. *)
        "testTheSeasonsRunNewestFirst",
        fun () ->
          let years = List.map (fun (s : Calendar.season) -> s.season) Calendar.seasons in
          assert_true (years = List.rev (List.sort compare years)) );
    ] )
