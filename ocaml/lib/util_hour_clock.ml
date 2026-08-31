(** Wall-clock time-of-day in milliseconds since midnight.

    Invariant: 0 <= ms < day_ms. [Util_duration.of_string] accepts [H:MM:SS],
    [M:SS], and [SS] interchangeably; Hour, in contrast, only accepts strict
    time-of-day values with two colons and a result below 24h.

    [offset_from elapsed_ms] computes [(hour_ms - elapsed_ms) mod 24h], so an
    endurance-race day-rollover (hour wraps at 24h while elapsed keeps growing)
    is handled internally -- callers can compare offsets directly without
    thinking about midnight. *)

let day_ms = 86400000

type t = Hour of int

(** Accepts only [H:MM:SS.mmm] (two colons). Empty, [MM:SS], [SS], values >= 24h,
    and any other unparseable text return [Error raw] so the original input can
    be reported. *)
let parse raw =
  let trimmed = String.trim raw in
  let parts = Util_parse.split_on_char ':' trimmed in
  if List.length parts <> 3 then Error raw
  else
    match Util_duration.of_string trimmed with
    | Some d ->
      let ms = Util_duration.millis d in
      if ms >= 0 && ms < day_ms then Ok (Hour ms) else Error raw
    | None -> Error raw

let ms_since_midnight (Hour ms) = ms

(** [(self - elapsed_ms) mod 24h], normalized to [0, 24h). Integer division
    truncates toward zero, so a negative remainder is shifted up by day_ms. *)
let offset_from (Hour ms) elapsed_ms =
  let d = day_ms in
  let diff = ms - elapsed_ms in
  let q = diff / d in
  let r = diff - (q * d) in
  if r < 0 then r + d else r

let pad2 n = if n < 10 then Printf.sprintf "0%d" n else string_of_int n

let pad3 n =
  if n < 10 then Printf.sprintf "00%d" n else if n < 100 then Printf.sprintf "0%d" n else string_of_int n

(** Renders as [HH:MM:SS.mmm] with the hour zero-padded to two digits.
    [Util_duration.format] strips a leading zero hour (e.g. [0:01:35.365]), which
    would break byte-identity against WEC CSVs that always use two-digit hours. *)
let format (Hour ms) =
  let total_sec = ms / 1000 in
  let ms_part = ms - (total_sec * 1000) in
  let hr = total_sec / 3600 in
  let m = (total_sec - (hr * 3600)) / 60 in
  let s = total_sec - (hr * 3600) - (m * 60) in
  Printf.sprintf "%s:%s:%s.%s" (pad2 hr) (pad2 m) (pad2 s) (pad3 ms_part)
