module Duration = Util_duration
module Hour_clock = Util_hour_clock
module Calendar = Motorsport_calendar
module Car = Motorsport_car
module Events = Motorsport_events
module Track = Motorsport_track
open Util_json_encode
open Motorsport_wec

(** What the grid order was derived from. The timing feed carries no qualifying
    result, so all three are estimates read back off the race.

    [Lap1_s1] is the best of them: [HOUR - ELAPSED] is constant across every car,
    so all cars share one timing origin and a back-row car's delay reaching the
    line is already inside its S1. Little can change hands before the first
    split. *)
type basis =
  | Lap1_s1
  | Lap1_elapsed
  | Unknown

type starting_grid_entry = {
  position : int;
  car : Car.t;
}

type starting_grid = {
  basis : basis;
  entries : starting_grid_entry list;
}

(** How far the race ran, and when. The feed states none of it directly.

    [duration] is the observation and [time_limit] what it is taken to mean: a
    WEC round is scheduled in whole hours and the feed never says which. The two
    are kept apart so a reader can see the estimate beside what it was made from,
    as [basis] does for the grid order.

    [started_at] is carried by the feed only as [HOUR - ELAPSED], a difference
    constant across the whole file -- [Cli_stages_validation]'s HourElapsedOffset
    rule is there to say so -- which is why one lap is enough to read it.

    [lap_total] counts the laps the leader finished, not the laps in the file:
    every car ran its own. *)
type particulars = {
  started_at : Hour_clock.t option;
  duration : Duration.t;
  time_limit : Duration.t;
  lap_total : int;
}

(** The laps say nothing about which round they are -- no column carries the
    year, and the same race is run again the next one -- so that arrives from
    outside, as the calendar entry the run was working through. Which is why
    [season] and [date] are certain: without them the file was never opened. *)
type t = {
  name : string;
  season : int;
  date : string;
  race : particulars;
  track : Track.t;
  starting_grid : starting_grid;
}

type car_build = {
  build_car : Car.t;
  lap1_s1 : Duration.t option;
  lap1_elapsed : Duration.t option;
}

let later_of a b = if Duration.millis b > Duration.millis a then b else a
let started_at_of (lap : raw_lap) = Hour_clock.Hour (Hour_clock.offset_from lap.hour (Duration.millis lap.elapsed))

let floor_to_hour d =
  let hour_ms = 3600000 in
  Duration.of_millis (Duration.millis d / hour_ms * hour_ms)

let particulars_of raw_laps =
  let duration = List.fold_left (fun acc (lap : raw_lap) -> later_of acc lap.elapsed) Duration.zero raw_laps in
  {
    started_at = (match raw_laps with [] -> None | lap :: _ -> Some (started_at_of lap));
    duration;
    time_limit = floor_to_hour duration;
    lap_total = List.fold_left (fun acc (lap : raw_lap) -> max acc lap.lap_number) 0 raw_laps;
  }

let lap1_s1_of (lap : raw_lap) = if lap.lap_number = 1 then lap.s1.value else None
let lap1_elapsed_of (lap : raw_lap) = if lap.lap_number = 1 then Some lap.elapsed else None
let append_unique xs x = if List.mem x xs then xs else xs @ [ x ]
let keep_first seen candidate = match seen with Some _ -> seen | None -> candidate

let build_from_lap (lap : raw_lap) =
  (* The Rust version normalizes unknown class values to Class::None; omitted
     because the Elm side consumes the raw values. *)
  let car : Car.t =
    {
      car_number = lap.car.car_number;
      drivers = [ lap.driver.name ];
      class_ = lap.car.class_;
      group = lap.car.group;
      team = lap.car.team;
      manufacturer = lap.car.manufacturer;
    }
  in
  { build_car = car; lap1_s1 = lap1_s1_of lap; lap1_elapsed = lap1_elapsed_of lap }

let update_build_with_lap build (lap : raw_lap) =
  let updated_car = { build.build_car with Car.drivers = append_unique build.build_car.Car.drivers lap.driver.name } in
  {
    build_car = updated_car;
    lap1_s1 = keep_first build.lap1_s1 (lap1_s1_of lap);
    lap1_elapsed = keep_first build.lap1_elapsed (lap1_elapsed_of lap);
  }

let upsert_build acc (lap : raw_lap) =
  if List.exists (fun b -> b.build_car.Car.car_number = lap.car.car_number) acc then
    List.map (fun b -> if b.build_car.Car.car_number = lap.car.car_number then update_build_with_lap b lap else b) acc
  else acc @ [ build_from_lap lap ]

let build_cars raw_laps = List.fold_left upsert_build [] raw_laps

(** Chosen once for the whole grid, so what gets compared is always the same
    measurement: a first split weighed against another car's whole first lap
    would order the two by their units rather than by their pace. A car that
    turned no first lap can be read by neither, so it does not cost the rest of
    the field its S1. *)
let basis_of builds =
  let readable = List.filter (fun b -> b.lap1_elapsed <> None) builds in
  if readable = [] then Unknown
  else if List.for_all (fun b -> b.lap1_s1 <> None) readable then Lap1_s1
  else Lap1_elapsed

let reading_for basis b =
  match basis with Lap1_s1 -> b.lap1_s1 | Lap1_elapsed -> b.lap1_elapsed | Unknown -> None

(** The tie-breaks are here so that the same input always yields the same output
    and the CSV's row order never leaks in. The last of them compares car numbers
    as the strings they are: any total order settles a tie, and reading them as
    numbers would dress the position up as a ranking it is not making -- nor
    would it be one-to-one, since Le Mans runs #7 alongside #007.

    A car with no first lap is placed rather than dropped: it did start the race,
    and the back is where being wrong costs the least. *)
let ordering_key basis b =
  let cn = b.build_car.Car.car_number in
  let elapsed = Option.value b.lap1_elapsed ~default:Duration.zero in
  match reading_for basis b with
  | Some reading -> (0, reading, elapsed, cn)
  | None -> (1, Duration.zero, Duration.zero, cn)

let estimate_grid builds =
  let basis = basis_of builds in
  let entries =
    builds
    |> List.stable_sort (fun a b -> compare (ordering_key basis a) (ordering_key basis b))
    |> List.mapi (fun i b -> { position = i + 1; car = b.build_car })
  in
  { basis; entries }

let from_raw_laps (entry : Calendar.entry) raw_laps =
  let builds = build_cars raw_laps in
  {
    name = Events.display_name entry.entry_id;
    season = entry.entry_season;
    date = entry.entry_date;
    race = particulars_of raw_laps;
    track = Track.from_raw_laps (Events.direction entry.entry_id) raw_laps;
    starting_grid = estimate_grid builds;
  }

let basis_to_string = function Lap1_s1 -> "lap1_s1" | Lap1_elapsed -> "lap1_elapsed" | Unknown -> "unknown"
let driver_to_json name = Json_object [ ("name", Json_string name) ]

let car_to_json (car : Car.t) =
  Json_object
    [
      ("carNumber", Json_string car.car_number);
      ("drivers", Json_array (List.map driver_to_json car.drivers));
      ("class", Json_string car.class_);
      ("group", Json_string car.group);
      ("team", Json_string car.team);
      ("manufacturer", Json_string car.manufacturer);
    ]

let to_grid_entry_json entry =
  Json_object [ ("position", Json_int entry.position); ("car", car_to_json entry.car) ]

let grid_to_json grid =
  Json_object
    [
      ("basis", Json_string (basis_to_string grid.basis));
      ("entries", Json_array (List.map to_grid_entry_json grid.entries));
    ]

let particulars_to_json p =
  let started_at =
    match p.started_at with None -> [] | Some h -> [ ("startedAt", Json_string (Hour_clock.format h)) ]
  in
  Json_object
    (started_at
    @ [
        ("duration", Json_string (Duration.format p.duration));
        ("timeLimit", Json_string (Duration.format p.time_limit));
        ("lapTotal", Json_int p.lap_total);
      ])

let to_json meta =
  Json_object
    [
      ("name", Json_string meta.name);
      ("season", Json_int meta.season);
      ("date", Json_string meta.date);
      ("race", particulars_to_json meta.race);
      ("track", Track.to_json meta.track);
      ("startingGrid", grid_to_json meta.starting_grid);
    ]
