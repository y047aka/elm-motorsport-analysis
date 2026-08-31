open Motorsport_cli
open Harness
module File_task = Cli_file_task
module Unlisted = Cli_stages_unlisted

let tasks root = File_task.from_calendar root

(** A CSV every run is expected to find, spelled the way the walk returns it. *)
let listed_csv = "../app/static/wec/2025/spa_6h.csv"

let suite =
  ( "Cli.Stages.TestUnlisted",
    [
      ( "testACsvOnTheCalendarIsNotReported",
        fun () ->
          let found = [ listed_csv; "../app/static/wec/2026/imola_6h.csv" ] in
          assert_true (Unlisted.detect (tasks "../app/static/wec") found = []) );
      ( "testACsvNoRoundNamesIsReported",
        fun () ->
          let stray = "../app/static/wec/2025/monza_6h.csv" in
          let found = [ listed_csv; stray ] in
          assert_true (Unlisted.detect (tasks "../app/static/wec") found = [ stray ]) );
      ( (* 2024 ran no round at Imola, so a file that looks right in every way
           but the year it is filed under is still not on the calendar. *)
        "testARoundFiledUnderTheWrongSeasonIsReported",
        fun () ->
          let found = [ "../app/static/wec/2024/imola_6h.csv" ] in
          assert_true (List.length (Unlisted.detect (tasks "../app/static/wec") found) = 1) );
      ( (* The half that used to be wrong: both sides name the same file and only
           the root is spelled differently. *)
        "testTheSpellingOfTheRootDoesNotMatter",
        fun () ->
          let found = [ listed_csv ] in
          assert_true (Unlisted.detect (tasks "../app/static/wec/") found = []);
          assert_true (Unlisted.detect (tasks "../app/static/./wec") found = []);
          assert_true (Unlisted.detect (tasks "/srv/app/static/wec") found = []) );
      ( "testAFileOutsideASeasonDirectoryIsReported",
        fun () ->
          let found = [ "../app/static/wec/spa_6h.csv"; "../app/static/wec/2025/old/spa_6h.csv" ] in
          assert_true (List.length (Unlisted.detect (tasks "../app/static/wec") found) = 2) );
    ] )
