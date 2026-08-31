type t = Duration of int

let zero = Duration 0
let of_millis ms = Duration ms
let millis (Duration ms) = ms
let add a b = Duration (millis a + millis b)

let zero_pad2 n = if n < 10 then Printf.sprintf "0%d" n else string_of_int n

let zero_pad3 n =
  if n < 10 then Printf.sprintf "00%d" n else if n < 100 then Printf.sprintf "0%d" n else string_of_int n

let format_millis ms =
  let total_sec = ms / 1000 in
  let ms_part = ms - (total_sec * 1000) in
  let h = total_sec / 3600 in
  let m = (total_sec - (h * 3600)) / 60 in
  let s = total_sec - (h * 3600) - (m * 60) in
  if h > 0 then Printf.sprintf "%d:%s:%s.%s" h (zero_pad2 m) (zero_pad2 s) (zero_pad3 ms_part)
  else if m > 0 then Printf.sprintf "%d:%s.%s" m (zero_pad2 s) (zero_pad3 ms_part)
  else Printf.sprintf "%d.%s" s (zero_pad3 ms_part)

let format d = format_millis (millis d)
let to_string = format

let parse_hms_to_seconds s =
  let int_of = Util_parse.int_of_string_opt in
  match Util_parse.split_on_char ':' s with
  | [ h; m; sec ] -> (
    match (int_of h, int_of m, int_of sec) with
    | Some hi, Some mi, Some si -> Some ((hi * 3600) + (mi * 60) + si)
    | _ -> None)
  | [ m; sec ] -> (
    match (int_of m, int_of sec) with Some mi, Some si -> Some ((mi * 60) + si) | _ -> None)
  | [ sec ] -> int_of sec
  | _ -> None

let pad_fractional_to_ms s =
  let len = String.length s in
  if len >= 3 then String.sub s 0 3 else s ^ String.make (3 - len) '0'

let of_string s =
  if s = "" then None
  else
    match Util_parse.split_on_char '.' s with
    | [ whole_part; ms_part ] -> (
      match (parse_hms_to_seconds whole_part, Util_parse.int_of_string_opt (pad_fractional_to_ms ms_part)) with
      | Some seconds, Some millis -> Some (Duration ((seconds * 1000) + millis))
      | _ -> None)
    | [ whole_only ] -> Option.map (fun secs -> Duration (secs * 1000)) (parse_hms_to_seconds whole_only)
    | _ -> None
