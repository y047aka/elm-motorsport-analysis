(** Missing is separated from unreadable because it means something specific now
    that the calendar drives the run: a round was listed and its CSV was never
    filed. *)
let read input_path =
  match Util_files.exists input_path with
  | Error e -> Error (Cli_errors.File e)
  | Ok false -> Error (Cli_errors.Input_path_not_found input_path)
  | Ok true -> (
    match Util_files.read_lines input_path with
    | Error e -> Error (Cli_errors.File e)
    | Ok [] -> Error (Cli_errors.Empty_file input_path)
    | Ok lines -> Ok (String.concat "\n" lines))
