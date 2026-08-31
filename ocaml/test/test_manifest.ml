open Motorsport_cli
open Harness
module Calendar = Motorsport_calendar
module Manifest = Cli_stages_manifest

let contains substr s =
  let n = String.length substr and m = String.length s in
  let rec go i = i + n <= m && (String.sub s i n = substr || go (i + 1)) in
  n = 0 || go 0

let rendered url_root = Util_json_encode.render (Manifest.to_json url_root Calendar.seasons)

let suite =
  ( "Cli.Stages.TestManifest",
    [
      ( "testTheCalendarJsonCarriesEverySeasonWithItsRoundsNamed",
        fun () ->
          let json = rendered "/static/wec" in
          assert_true (contains "\"seasons\"" json);
          assert_true (contains "\"id\": \"le_mans_24h\"" json);
          assert_true (contains "\"name\": \"24 Hours of Le Mans\"" json);
          assert_true (contains "\"date\": \"2024-06-15\"" json) );
      ( (* The app fetches these rather than building them. *)
        "testEveryRoundStatesWhereItsFilesAre",
        fun () ->
          let json = rendered "/static/wec" in
          assert_true (contains "\"summary\": \"/static/wec/2025/spa_6h.json\"" json);
          assert_true (contains "\"laps\": \"/static/wec/2025/spa_6h_laps.jsonl\"" json) );
      ( (* Nothing about where the app serves from reaches the calendar, so
           moving it is one edit here and not one on each side. *)
        "testTheUrlRootIsTheCallersToGive",
        fun () ->
          let json = rendered "/elsewhere" in
          assert_true (contains "\"summary\": \"/elsewhere/2026/imola_6h.json\"" json);
          assert_true (not (contains "/static/wec" json)) );
      ( (* The manifest is a rendering of whatever it is handed, not of the one
           calendar the CLI happens to hold. *)
        "testAnEmptyCalendarRendersAnEmptyManifest",
        fun () ->
          let json = Util_json_encode.render (Manifest.to_json "/static/wec" []) in
          assert_true (contains "\"seasons\"" json);
          assert_true (not (contains "\"season\":" json)) );
    ] )
