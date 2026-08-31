let write (task : Cli_file_task.t) (rendered : Cli_stages_transform.rendered) =
  match Util_files.write task.output_path rendered.metadata_json with
  | Error e -> Error (Cli_errors.File e)
  | Ok () -> (
    match Util_files.write task.laps_path rendered.laps_jsonl with
    | Error e -> Error (Cli_errors.File e)
    | Ok () -> Ok ())
