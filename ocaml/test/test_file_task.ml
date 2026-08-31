open Motorsport_cli
open Harness
module Calendar = Motorsport_calendar
module File_task = Cli_file_task

let task_for season id =
  File_task.from_calendar "../app/static/wec"
  |> List.find_opt (fun (t : File_task.t) ->
         t.entry.Calendar.entry_season = season && t.entry.Calendar.entry_id = id)

let suite =
  ( "Cli.TestFileTask",
    [
      ( "testEveryPathHangsOffTheRootAndTheCalendarEntry",
        fun () ->
          match task_for 2025 "fuji_6h" with
          | None -> assert_true false
          | Some (task : File_task.t) ->
            assert_true (task.input_path = "../app/static/wec/2025/fuji_6h.csv");
            assert_true (task.output_path = "../app/static/wec/2025/fuji_6h.json");
            assert_true (task.laps_path = "../app/static/wec/2025/fuji_6h_laps.jsonl");
            assert_true (task.entry.Calendar.entry_date = "2025-09-28") );
      ( (* The same round in two seasons is two tasks writing to two places,
           which is the whole reason the season cannot be left to the id. *)
        "testTheSameRoundInTwoSeasonsIsTwoTasks",
        fun () ->
          match (task_for 2025 "spa_6h", task_for 2026 "spa_6h") with
          | Some (a : File_task.t), Some (b : File_task.t) ->
            assert_true (a.output_path = "../app/static/wec/2025/spa_6h.json");
            assert_true (b.output_path = "../app/static/wec/2026/spa_6h.json")
          | _ -> assert_true false );
      ( "testTheLabelNamesTheRoundNotJustTheFile",
        fun () ->
          match task_for 2026 "le_mans_24h" with
          | None -> assert_true false
          | Some task -> assert_true (File_task.label task = "2026/le_mans_24h") );
    ] )
