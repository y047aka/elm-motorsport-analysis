module Calendar = Motorsport_calendar
module Events = Motorsport_events
module Extra = Util_json_encode_extra
open Util_json_encode

(** Where the app serves the season directories from -- the one place the app's
    layout is written down, and the reason it is here rather than in
    [Motorsport_calendar], which is a list of races.

    Not where the files are written to. That is the run's argument, and
    [../app/static/wec] and [/static/wec] are the same place reached two
    different ways. *)
let url_root = "/static/wec"

let round_to_json url_root season (r : Calendar.round) =
  let stem = Printf.sprintf "%s/%d/%s" url_root season r.id in
  Json_object
    [
      ("id", Json_string r.id);
      ("name", Json_string (Events.display_name r.id));
      ("date", Json_string r.date);
      ("summary", Json_string (stem ^ ".json"));
      ("laps", Json_string (stem ^ "_laps.jsonl"));
    ]

let season_to_json url_root (s : Calendar.season) =
  Json_object
    [
      ("season", Json_int s.season);
      ("rounds", Json_array (List.map (round_to_json url_root s.season) s.rounds));
    ]

(** The file the app reads before it has asked for a round.

    The paths are stated rather than left to a rule the reader reproduces. A
    convention both sides know is two copies of it, and the app has no way to
    notice when its copy stops matching where the files went. *)
let to_json url_root seasons = Json_object [ ("seasons", Json_array (List.map (season_to_json url_root) seasons)) ]

(** Written beside the season directories rather than inside one, because it
    spans all of them. *)
let write root =
  let path = root ^ "/index.json" in
  Util_files.write path (Extra.render (to_json url_root Calendar.seasons))
  |> Result.map_error (fun e -> Cli_errors.File e)
  |> Result.map (fun () -> path)
