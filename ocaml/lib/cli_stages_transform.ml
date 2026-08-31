module Extra = Util_json_encode_extra
module Metadata = Motorsport_metadata
module Wec = Motorsport_wec

type rendered = {
  lap_count : int;
  metadata_json : string;
  laps_jsonl : string;
}

let render_jsonl raw_laps =
  raw_laps |> List.map (fun raw_lap -> Extra.render_on_one_line (Wec.to_json raw_lap) ^ "\n") |> String.concat ""

let transform entry raw_laps =
  let metadata = Metadata.from_raw_laps entry raw_laps in
  let metadata_json = Extra.render (Metadata.to_json metadata) in
  let laps_jsonl = render_jsonl raw_laps in
  { lap_count = List.length raw_laps; metadata_json; laps_jsonl }
