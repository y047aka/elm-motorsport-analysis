module File_task = Cli_file_task
module Csv_decode = Cli_stages_csv_decode
module Csv_input = Cli_stages_csv_input
module Manifest = Cli_stages_manifest
module Output = Cli_stages_output
module Transform = Cli_stages_transform
module Unlisted = Cli_stages_unlisted
module Validation = Cli_stages_validation

type processing_report = {
  lap_count : int;
  output_path : string;
  laps_path : string;
}

type run_summary = {
  processed : int;
  errors : int;
}

let decode (task : File_task.t) content = Csv_decode.decode task.input_path content

let report_violations (task : File_task.t) raw_laps =
  Validation.validate task.entry.Motorsport_calendar.entry_id raw_laps |> List.iter prerr_endline;
  raw_laps

let render (task : File_task.t) raw_laps = Transform.transform task.entry raw_laps

let write (task : File_task.t) (rendered : Transform.rendered) =
  Output.write task rendered |> Result.map (fun () -> rendered)

let to_report (task : File_task.t) (rendered : Transform.rendered) =
  { lap_count = rendered.lap_count; output_path = task.output_path; laps_path = task.laps_path }

let process_file (task : File_task.t) =
  Csv_input.read task.input_path
  |> Fun.flip Result.bind (decode task)
  |> Result.map (report_violations task)
  |> Result.map (render task)
  |> Fun.flip Result.bind (write task)
  |> Result.map (to_report task)

(** Not an error: the run converted everything it was asked for, and this is
    about what it was not asked for. Saying it is what keeps a forgotten line in
    [Motorsport_calendar] from passing for a clean run. *)
let report_unlisted_csv_files root tasks =
  match Util_files.walk_csv_files root with
  | Error e -> prerr_endline (Printf.sprintf "Calendar: could not check for unlisted CSV files (%s)" (Util_files.file_error_to_string e))
  | Ok found ->
    Unlisted.detect tasks found
    |> List.iter (fun path -> prerr_endline (Printf.sprintf "Calendar: %s is not on the calendar, skipped" path))

(** Written once for the run, not once per file, and written even by a run that
    decoded nothing: the calendar is not made from the laps. *)
let write_calendar root =
  match Manifest.write root with
  | Ok path ->
    print_endline (Printf.sprintf "Calendar -> %s" path);
    0
  | Error e ->
    prerr_endline (Printf.sprintf "Calendar: %s" (Cli_errors.to_string e));
    1

(** The calendar is the worklist, so a run converts the rounds it holds and
    nothing else. Two ways that can be wrong, and both are said out loud: a round
    with no CSV fails the run, and a CSV no round names is reported and left
    alone. *)
let run_all root =
  let tasks = File_task.from_calendar root in
  let summary =
    List.fold_left
      (fun acc task ->
        match process_file task with
        | Ok report ->
          print_endline (Printf.sprintf "%s: Wrote %d laps" (File_task.label task) report.lap_count);
          print_endline (Printf.sprintf "%s: Metadata -> %s" (File_task.label task) report.output_path);
          print_endline (Printf.sprintf "%s: Laps     -> %s" (File_task.label task) report.laps_path);
          { acc with processed = acc.processed + 1 }
        | Error e ->
          prerr_endline (Printf.sprintf "%s: %s" (File_task.label task) (Cli_errors.to_string e));
          { acc with errors = acc.errors + 1 })
      { processed = 0; errors = 0 } tasks
  in
  report_unlisted_csv_files root tasks;
  let calendar_errors = write_calendar root in
  let errors = summary.errors + calendar_errors in
  print_endline (Printf.sprintf "Processing completed: %d processed, %d errors" summary.processed errors);
  if errors = 0 then 0 else 1
