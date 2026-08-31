(** A CSV's round identity: the directory it sits in and the file it is.

    The two sides being compared are spelled by different means -- one built from
    a calendar entry, the other returned by a walk -- so everything above these
    two segments is dropped rather than trusted to match. That is what survives a
    trailing slash on the root, a [./] in the middle, and an absolute path
    meeting a relative one. *)
let round_key path =
  match
    Util_parse.split_on_char '/' path |> List.filter (fun seg -> seg <> "" && seg <> ".") |> List.rev
  with
  | name :: dir :: _ -> (dir, name)
  | [ name ] -> ("", name)
  | [] -> ("", "")

(** The CSV files under the root that no round on the calendar names.

    Kept apart from the walk that finds them because this is the half that can be
    wrong unnoticed: the run still writes exactly what it should, and only the
    warnings are junk. *)
let detect tasks found =
  let listed = tasks |> List.map (fun (task : Cli_file_task.t) -> round_key task.input_path) in
  found |> List.filter (fun path -> not (List.mem (round_key path) listed))
