open Motorsport_cli

(** Checked once here rather than once per round, so a mistyped root reads as one
    mistake instead of as every race being missing. *)
let check_root root =
  match Util_files.exists root with
  | Error e -> Error (Cli_errors.File e)
  | Ok false -> Error (Cli_errors.Input_path_not_found root)
  | Ok true -> (
    match Util_files.is_directory root with
    | Error e -> Error (Cli_errors.File e)
    | Ok false -> Error (Cli_errors.Root_not_a_directory root)
    | Ok true -> Ok ())

let () =
  let args = List.tl (Array.to_list Sys.argv) in
  let code =
    match Cli_args.parse args with
    | Error e ->
      prerr_endline (Printf.sprintf "Error: %s" (Cli_args.args_error_to_string e));
      prerr_endline (Cli_args.usage ());
      1
    | Ok parsed -> (
      match check_root parsed.root with
      | Error e ->
        prerr_endline (Printf.sprintf "Error: %s" (Cli_errors.to_string e));
        1
      | Ok () -> Cli_stages.run_all parsed.root)
  in
  exit code
