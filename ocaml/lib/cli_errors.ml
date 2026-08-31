type t =
  | Input_path_not_found of string
  | Root_not_a_directory of string
  | Empty_file of string
  | File of Util_files.file_error
  | Csv of { path : string; message : string }

let to_string = function
  | Input_path_not_found p -> Printf.sprintf "Path not found: %s" p
  | Root_not_a_directory p ->
    Printf.sprintf "Not a directory: %s (expected the directory holding the season directories)" p
  | Empty_file p -> Printf.sprintf "Empty file: %s" p
  | File cause -> Util_files.file_error_to_string cause
  | Csv r -> Printf.sprintf "Failed to decode %s (caused by: %s)" r.path r.message
