type file_error =
  | Read_error of string * string (* path, underlying message *)
  | Write_error of string * string
  | Access_error of string (* failure to obtain path stat / existence *)
  | Glob_error of string

let file_error_to_string = function
  | Read_error (path, msg) -> Printf.sprintf "Failed to read %s (caused by: %s)" path msg
  | Write_error (path, msg) -> Printf.sprintf "Failed to write %s (caused by: %s)" path msg
  | Access_error msg -> Printf.sprintf "File access error (caused by: %s)" msg
  | Glob_error msg -> Printf.sprintf "Directory glob error (caused by: %s)" msg

let read_all path =
  let channel = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in_noerr channel)
    (fun () -> really_input_string channel (in_channel_length channel))

(** Splits on CR, LF or CRLF and drops the empty piece a final terminator leaves,
    which is what the JVM's line reader hands Flix. *)
let split_lines content =
  let length = String.length content in
  let rec go start i acc =
    if i >= length then if start >= length then List.rev acc else List.rev (String.sub content start (length - start) :: acc)
    else
      match content.[i] with
      | '\n' -> go (i + 1) (i + 1) (String.sub content start (i - start) :: acc)
      | '\r' ->
        let next = if i + 1 < length && content.[i + 1] = '\n' then i + 2 else i + 1 in
        go next next (String.sub content start (i - start) :: acc)
      | _ -> go start (i + 1) acc
  in
  go 0 0 []

let read_lines path =
  try Ok (split_lines (read_all path)) with
  | Sys_error msg -> Error (Read_error (path, msg))
  | End_of_file -> Error (Read_error (path, "unexpected end of file"))

let write path content =
  try
    let channel = open_out_bin path in
    Fun.protect ~finally:(fun () -> close_out_noerr channel) (fun () -> output_string channel content);
    Ok ()
  with Sys_error msg -> Error (Write_error (path, msg))

let exists path = try Ok (Sys.file_exists path) with Sys_error msg -> Error (Access_error msg)

let is_directory path =
  try Ok (Sys.file_exists path && Sys.is_directory path) with Sys_error msg -> Error (Access_error msg)

(** Recursively finds every [.csv] file under [dir_path]. *)
let walk_csv_files dir_path =
  let rec walk dir =
    Sys.readdir dir |> Array.to_list |> List.sort compare
    |> List.concat_map (fun entry ->
           let path = Filename.concat dir entry in
           if Sys.is_directory path then walk path
           else if Filename.check_suffix path ".csv" then [ path ]
           else [])
  in
  try Ok (walk dir_path) with Sys_error msg -> Error (Glob_error msg)
