module Calendar = Motorsport_calendar

(** One round's files, built from a calendar entry and the root the run was
    pointed at. The calendar names the round and the path follows, so there is
    nothing to read back off a directory name. *)
type t = {
  input_path : string;
  output_path : string;
  laps_path : string;
  entry : Calendar.entry;
}

(** Every round the calendar holds, under [root]. A CSV no entry names is not
    here, so it is never read; [Cli_stages_unlisted] reports those. *)
let from_calendar root =
  Calendar.entries
  |> List.map (fun (entry : Calendar.entry) ->
         let stem = Printf.sprintf "%s/%d/%s" root entry.entry_season entry.entry_id in
         {
           input_path = stem ^ ".csv";
           output_path = stem ^ ".json";
           laps_path = stem ^ "_laps.jsonl";
           entry;
         })

(** How a round is named in the run's output. The display name would not say
    which of two seasons a line is about. *)
let label task = Printf.sprintf "%d/%s" task.entry.Calendar.entry_season task.entry.Calendar.entry_id
