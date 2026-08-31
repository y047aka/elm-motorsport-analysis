(** Source-data integrity checks run during CSV -> JSON conversion.

    All rules use strict 0 ms equality. Violations are returned as warnings only;
    they do not affect the exit code. [Cli_stages.process_file] prints them to
    stderr.

    Rules:
    + SectorSum -- [s1 + s2 + s3 = lapTime] (per row)
    + ElapsedDrift -- per car, [elapsed[n] = sum(lapTime[1..=n])] (cumulative-sum:
      every row from the first drift onward is reported)
    + HourElapsedOffset -- across the CSV, [(hour - elapsed) mod 24h] is constant
    + MiniSectorSum -- when mini-sectors present, [sum(time) = lapTime] (blank
      [time] counted as zero). Skipped on pit laps and Ford-chicane track-limits
      signatures (see below).
    + MiniSectorElapsedMonotonic -- when mini-sectors present, [elapsed] values
      are strictly increasing in track order. Equality is reported (two timing
      loops cannot fire at the same millisecond). Always run, even on pit laps.

    Design notes:
    - HourElapsedOffset's baseline is the {b first valid row in the whole CSV}
      (race-wide, not per-car). A bad lap 1 on one car does not cascade across the
      rest of that car.
    - 24h wrap is folded into [Util_hour_clock.offset_from], so the validator just
      compares offsets with [=].
    - Report order follows CSV appearance (per-lap is naturally CSV order; per-car
      uses first-seen-index to sort the car groups).
    - Mini-sector rules silently skip laps where [mini_sectors = None] (non-Le
      Mans rounds, or laps where all 30 source columns were blank).
    - {b MiniSectorSum pit-lap skip} -- pit-entry laps bypass main-line markers
      (typically FORDOUT and FL_time) so the sum can never reach lapTime.
      Identified by [crossing_finish_line_in_pit] or [pit_time <> None].
    - {b MiniSectorSum track-limits skip} -- running off the Ford chicanes leaves
      a known blank pattern (SCL1+FORDOUT for the second chicane, PITREF+SCL1 for
      the first). These are the dominant non-pit cause of residual sum mismatches
      in Le Mans 2025. *)

module Duration = Util_duration
module Hour_clock = Util_hour_clock
module Mini_sector = Motorsport_mini_sector
module String_map = Map.Make (String)
open Motorsport_wec

type violation =
  (** [s1 + s2 + s3 <> lapTime]. Args: lap / lapTime / sector sum / labels of
      blank sectors. *)
  | Sector_sum of raw_lap * Duration.t * Duration.t * string list
  (** [elapsed[n] <> sum(lapTime[1..=n])]. Cumulative-sum based, so every row
      from the first drift onward is reported (sticky drift). Args: lap /
      expected = running sum / actual = elapsed. *)
  | Elapsed_drift of raw_lap * Duration.t * Duration.t
  (** [(hour - elapsed) mod 24h] does not match the baseline. Args: lap /
      baseline offset (ms, signed) / actual offset (ms, signed). *)
  | Hour_elapsed_offset of raw_lap * int * int
  (** [sum(mini_sector.time) <> lapTime]. Args: lap / lapTime / sum / IDs of
      sub-sectors with blank time (in track order). *)
  | Mini_sector_sum of raw_lap * Duration.t * Duration.t * Mini_sector.t list
  (** Mini-sector [elapsed[i] <= elapsed[i-1]] for some adjacent pair in track
      order. Only entries where both sides are present are compared. Args: lap /
      prev id / prev elapsed / curr id / curr elapsed. *)
  | Mini_sector_elapsed_monotonic of raw_lap * Mini_sector.t * Duration.t * Mini_sector.t * Duration.t

let result_to_option = function Ok _ -> None | Error v -> Some v

let sector_or_zero sector name = match sector with Some d -> (d, None) | None -> (Duration.zero, Some name)

let check_sector_sum (lap : raw_lap) =
  let lap_time = lap.lap_time in
  let s1, s1_blank = sector_or_zero lap.s1.value "s1" in
  let s2, s2_blank = sector_or_zero lap.s2.value "s2" in
  let s3, s3_blank = sector_or_zero lap.s3.value "s3" in
  let sum = Duration.add (Duration.add s1 s2) s3 in
  if sum = lap_time then Ok ()
  else
    let blanks = List.filter_map Fun.id [ s1_blank; s2_blank; s3_blank ] in
    Error (Sector_sum (lap, lap_time, sum, blanks))

(** Cumulative-sum elapsed-drift check (equivalent to Rust's [scan]). Each lap
    updates [running = sum(lapTime[1..=n])] and is flagged if [elapsed]
    disagrees. Once a drift starts, every subsequent lap is reported -- noisier
    than adjacent-diff, but catches compensating drift. *)
let check_elapsed_drift sorted_laps =
  let _, acc =
    List.fold_left
      (fun (running, acc) (lap : raw_lap) ->
        let new_run = Duration.add running lap.lap_time in
        let elapsed = lap.elapsed in
        if new_run = elapsed then (new_run, acc) else (new_run, Elapsed_drift (lap, new_run, elapsed) :: acc))
      (Duration.zero, []) sorted_laps
  in
  List.rev acc

(** Groups laps by car number while preserving CSV appearance order:
    + first pass records car number -> first-seen index
    + second pass collects car number -> all laps
    + flatten, sorted by first-seen index *)
let group_by_car laps =
  let first_seen =
    List.fold_left
      (fun acc (lap : raw_lap) ->
        if String_map.mem lap.car.car_number acc then acc
        else String_map.add lap.car.car_number (String_map.cardinal acc) acc)
      String_map.empty laps
  in
  let grouped =
    List.fold_left
      (fun acc (lap : raw_lap) ->
        String_map.update lap.car.car_number
          (function None -> Some [ lap ] | Some existing -> Some (existing @ [ lap ]))
          acc)
      String_map.empty laps
  in
  let index car = Option.value (String_map.find_opt car first_seen) ~default:0 in
  String_map.bindings grouped |> List.stable_sort (fun (a, _) (b, _) -> compare (index a) (index b))

(** Walks per-car elapsed-drift checks in CSV order (first-seen index). Each
    car's laps are sorted by lap number before the check. *)
let per_car_violations laps =
  group_by_car laps
  |> List.concat_map (fun (_, car_laps) ->
         let sorted =
           List.stable_sort (fun (a : raw_lap) (b : raw_lap) -> compare a.lap_number b.lap_number) car_laps
         in
         check_elapsed_drift sorted)

let check_hour_line (lap : raw_lap) base =
  let offset = Hour_clock.offset_from lap.hour (Duration.millis lap.elapsed) in
  if offset = base then Ok () else Error (Hour_elapsed_offset (lap, base, offset))

let check_hour_elapsed_race_wide laps =
  match laps with
  | [] -> []
  | (lap : raw_lap) :: _ ->
    let base = Hour_clock.offset_from lap.hour (Duration.millis lap.elapsed) in
    laps |> List.filter_map (fun l -> result_to_option (check_hour_line l base))

let is_pit_lap (lap : raw_lap) = lap.crossing_finish_line_in_pit || lap.pit_time <> None

let check_mini_sector_sum (lap : raw_lap) list =
  let sum, blanks_rev =
    List.fold_left
      (fun (acc_sum, acc_blanks) (id, (sector : raw_mini_sector)) ->
        match sector.time with
        | Some d -> (Duration.add acc_sum d, acc_blanks)
        | None -> (acc_sum, id :: acc_blanks))
      (Duration.zero, []) list
  in
  let blanks = List.rev blanks_rev in
  if sum = lap.lap_time then []
  else if Mini_sector.is_track_limits_signature blanks then []
  else [ Mini_sector_sum (lap, lap.lap_time, sum, blanks) ]

(** Reports each adjacent pair where the second elapsed is [<=] the first.
    Blank-elapsed entries are skipped without breaking the chain. *)
let check_mini_sector_monotonic (lap : raw_lap) list =
  let _, acc =
    List.fold_left
      (fun (prev, acc) (id, (sector : raw_mini_sector)) ->
        match (sector.mini_elapsed, prev) with
        | None, _ -> (prev, acc)
        | Some curr, None -> (Some (id, curr), acc)
        | Some curr, Some (prev_id, prev_elapsed) ->
          let new_acc =
            if Duration.millis curr > Duration.millis prev_elapsed then acc
            else Mini_sector_elapsed_monotonic (lap, prev_id, prev_elapsed, id, curr) :: acc
          in
          (Some (id, curr), new_acc))
      (None, []) list
  in
  List.rev acc

let check_mini_sectors (lap : raw_lap) =
  match lap.mini_sectors with
  | None -> []
  | Some list ->
    let sum_viol = if is_pit_lap lap then [] else check_mini_sector_sum lap list in
    let mono_viol = check_mini_sector_monotonic lap list in
    sum_viol @ mono_viol

let detect laps =
  let per_lap = laps |> List.filter_map (fun lap -> result_to_option (check_sector_sum lap)) in
  let per_car = per_car_violations laps in
  let per_race = check_hour_elapsed_race_wide laps in
  let per_mini = laps |> List.concat_map check_mini_sectors in
  per_lap @ per_car @ per_race @ per_mini

(** Same shape as [format_duration_pair] but with caller-supplied labels. *)
let format_labelled_duration_pair event_name (lap : raw_lap) kind left_label left_value right_label right_value =
  Printf.sprintf "%s: [car %s #%d] %s: %s=%s (%dms) %s=%s (%dms)" event_name lap.car.car_number lap.lap_number kind
    left_label (Duration.format left_value) (Duration.millis left_value) right_label (Duration.format right_value)
    (Duration.millis right_value)

(** Emits [{event_name}: [car X #N] kind: expected=<fmt> (<ms>ms) actual=<fmt>
    (<ms>ms)]. The raw ms is included alongside the formatted duration to keep
    the output both human-readable and grep-friendly (matches Rust output). *)
let format_duration_pair event_name lap kind expected actual =
  format_labelled_duration_pair event_name lap kind "expected" expected "actual" actual

let format_signed_ms ms = if ms < 0 then "-" ^ Duration.format_millis (0 - ms) else Duration.format_millis ms

let format_signed_ms_pair event_name (lap : raw_lap) kind expected actual =
  Printf.sprintf "%s: [car %s #%d] %s: expected=%s (%dms) actual=%s (%dms)" event_name lap.car.car_number
    lap.lap_number kind (format_signed_ms expected) expected (format_signed_ms actual) actual

let format_violation event_name v =
  match v with
  | Sector_sum (lap, lap_time, sum, blanks) ->
    let suffix = if blanks = [] then "" else Printf.sprintf " (blank: %s)" (String.concat "," blanks) in
    format_duration_pair event_name lap "sector-sum" lap_time sum ^ suffix
  | Elapsed_drift (lap, expected, actual) -> format_duration_pair event_name lap "elapsed-drift" expected actual
  | Hour_elapsed_offset (lap, base, offset) -> format_signed_ms_pair event_name lap "hour-offset" base offset
  | Mini_sector_sum (lap, lap_time, sum, blanks) ->
    let suffix =
      if blanks = [] then ""
      else Printf.sprintf " (blank: %s)" (String.concat "," (List.map Mini_sector.json_key blanks))
    in
    format_duration_pair event_name lap "mini-sector-sum" lap_time sum ^ suffix
  | Mini_sector_elapsed_monotonic (lap, prev_id, prev_elapsed, curr_id, curr_elapsed) ->
    let kind =
      Printf.sprintf "mini-sector-elapsed[%s->%s]" (Mini_sector.json_key prev_id) (Mini_sector.json_key curr_id)
    in
    format_labelled_duration_pair event_name lap kind "prev" prev_elapsed "curr" curr_elapsed

let validate event_name laps = detect laps |> List.map (fun v -> format_violation event_name v)
