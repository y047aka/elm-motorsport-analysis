(** The circuit's proportions, which the Elm side reads straight off the summary
    rather than working out again.

    A stretch takes the share of the lap that its record does of every record put
    together, so the track is drawn to how quick each part of it is. Read off the
    whole file, so these are the records as the race left them and not as they
    stood at any moment of it -- a stretch's share is how quick it was at its
    quickest, and mid-race that answer is still moving. *)

module Duration = Util_duration
module Mini_sector = Motorsport_mini_sector
module Sector = Motorsport_sector
module Direction = Motorsport_circuit_direction
open Util_json_encode
open Motorsport_wec

(** Where a stretch begins and how much of the lap it takes, both as fractions of
    the whole. *)
type share = {
  start : float;
  share : float;
}

(** The whole lap, divided, and which way round it is driven. Both grains cover
    the same lap, so a car can be placed by either.

    [direction] is the one thing here not read off the laps, which say nothing
    about it -- see [Motorsport_events.direction]. *)
type t = {
  direction : Direction.t option;
  sectors : (Sector.t * share) list;
  mini_sectors : (Mini_sector.t * share) list option;
}

let sum xs = List.fold_left ( +. ) 0.0 xs

let ratios_over order time_of =
  let total =
    order |> List.filter_map time_of |> List.map Duration.millis |> List.fold_left ( + ) 0 |> float_of_int
  in
  fun id ->
    if total = 0.0 then 1.0 /. float_of_int (List.length order)
    else float_of_int (time_of id |> Option.map Duration.millis |> Option.value ~default:0) /. total

let start_of ratio order id =
  let rec take_while = function x :: rest when x <> id -> x :: take_while rest | _ -> [] in
  take_while order |> List.map ratio |> sum

let shares_over ratio order = order |> List.map (fun id -> (id, { start = start_of ratio order id; share = ratio id }))

let fastest time_of raw_laps =
  match raw_laps |> List.filter_map time_of with
  | [] -> None
  | first :: rest -> Some (List.fold_left (fun acc d -> if Duration.millis d < Duration.millis acc then d else acc) first rest)

let sector_time sector (lap : raw_lap) =
  match sector with Sector.S1 -> lap.s1.value | Sector.S2 -> lap.s2.value | Sector.S3 -> lap.s3.value

(** The feed writes a lap it did not record as [0.000], and the mini-sectors of
    such a lap are not a lap of the circuit either. *)
let mini_sector_time id (lap : raw_lap) =
  if Duration.millis lap.lap_time = 0 then None
  else
    Option.bind lap.mini_sectors (fun list ->
        Option.bind
          (List.find_opt (fun (other, _) -> other = id) list)
          (fun (_, (sector : raw_mini_sector)) -> sector.time))

let has_mini_sectors (lap : raw_lap) = match lap.mini_sectors with Some _ -> true | None -> false

let at_sector_grain direction raw_laps =
  let ratio = ratios_over Sector.all (fun sector -> fastest (sector_time sector) raw_laps) in
  { direction; sectors = shares_over ratio Sector.all; mini_sectors = None }

let at_mini_sector_grain direction raw_laps =
  let mini_ratio = ratios_over Mini_sector.all (fun id -> fastest (mini_sector_time id) raw_laps) in
  let sector_ratio sector =
    Mini_sector.all |> List.filter (fun id -> Mini_sector.sector_of id = sector) |> List.map mini_ratio |> sum
  in
  {
    direction;
    sectors = shares_over sector_ratio Sector.all;
    mini_sectors = Some (shares_over mini_ratio Mini_sector.all);
  }

(** Which grain the lap is divided at follows from what the feed carries, rather
    than from a list of event names. *)
let from_raw_laps direction raw_laps =
  if List.exists has_mini_sectors raw_laps then at_mini_sector_grain direction raw_laps
  else at_sector_grain direction raw_laps

let share_to_json share = Json_object [ ("start", Json_float share.start); ("share", Json_float share.share) ]

let to_json track =
  let direction =
    match track.direction with None -> [] | Some d -> [ ("direction", Json_string (Direction.json_value d)) ]
  in
  let sectors = track.sectors |> List.map (fun (sector, share) -> (Sector.json_key sector, share_to_json share)) in
  let mini_sectors =
    match track.mini_sectors with
    | None -> []
    | Some list ->
      let entries = list |> List.map (fun (id, share) -> (Mini_sector.json_key id, share_to_json share)) in
      [ ("miniSectors", Json_object entries) ]
  in
  Json_object (direction @ (("sectors", Json_object sectors) :: mini_sectors))
