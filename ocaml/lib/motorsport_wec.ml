module Decode = Util_csv_decode
module Extra = Util_csv_decode_extra
module Duration = Util_duration
module Hour_clock = Util_hour_clock
module Mini_sector = Motorsport_mini_sector
open Util_json_encode

(** Improvement flag observed in WEC LAP_IMPROVEMENT and S*_IMPROVEMENT columns.
    Semantics derived from empirical CSV analysis:

    - [No_improvement] = slower than this driver's personal best
    - [Driver_best] = this driver's PB, but another driver on the same car has
      already been faster (sector-only -- never observed on LAP_IMPROVEMENT)
    - [Car_best] = fastest across every driver of this car so far
    - [Overall_best] = fastest of every running car so far (at most once per race
      per column) *)
type improvement =
  | No_improvement
  | Driver_best
  | Car_best
  | Overall_best

(** Race flag state at the finish line when each lap was completed. Observed
    values across all WEC CSV files:

    - [Green] = GF -- normal racing conditions
    - [Slow_zone] = SF -- safety car or local slow zone active
    - [Full_course_yellow] = FCY -- full-course yellow, no overtaking
    - [Red] = RF -- race suspended
    - [Finish] = FF -- chequered flag (race end) *)
type flag =
  | Green
  | Slow_zone
  | Full_course_yellow
  | Red
  | Finish

type raw_sector = {
  value : Duration.t option;
  improvement : improvement;
}

(** One Le Mans mini-sector observation. [time] is the segment duration from the
    previous marker; [elapsed] is the cumulative time from the start of the lap.
    Both are optional because either column can be blank (pit laps, missed
    markers). *)
type raw_mini_sector = {
  time : Duration.t option;
  mini_elapsed : Duration.t option;
}

type raw_car = {
  car_number : string;
  class_ : string;
  group : string;
  team : string;
  manufacturer : string;
}

type raw_driver = {
  number : int;
  name : string;
}

type raw_lap = {
  car : raw_car;
  driver : raw_driver;
  lap_number : int;
  lap_time : Duration.t;
  lap_improvement : improvement;
  crossing_finish_line_in_pit : bool;
  s1 : raw_sector;
  s2 : raw_sector;
  s3 : raw_sector;
  kph : string;
  elapsed : Duration.t;
  hour : Hour_clock.t;
  top_speed : string;
  pit_time : Duration.t option;
  flag_at_fl : flag;
  mini_sectors : (Mini_sector.t * raw_mini_sector) list option;
}

let string_field name = Decode.field name (Decode.string ())
let int_field name = Decode.field name (Decode.int ())

let parse_numeric_string name s =
  match Util_parse.float_of_string_opt s with
  | Some _ -> Ok s
  | None -> Error (Printf.sprintf "%s: expected numeric but got \"%s\"" name s)

let numeric_string_field name =
  string_field name |> Decode.and_then (fun s -> Decode.from_result (parse_numeric_string name s))

let numeric_or_blank_string_field name =
  string_field name
  |> Decode.and_then (fun s ->
         match s with "" -> Decode.succeed s | _ -> Decode.from_result (parse_numeric_string name s))

let parse_duration name raw =
  match Duration.of_string raw with
  | Some d -> Ok d
  | None -> Error (Printf.sprintf "%s: expected duration but got \"%s\"" name raw)

let duration_field name = string_field name |> Decode.and_then (fun s -> Decode.from_result (parse_duration name s))

let parse_optional_duration name raw =
  match Duration.of_string raw with
  | Some d -> Ok (Some d)
  | None -> if raw = "" then Ok None else Error (Printf.sprintf "%s: expected duration but got \"%s\"" name raw)

let optional_duration_field name =
  string_field name |> Decode.and_then (fun s -> Decode.from_result (parse_optional_duration name s))

let hour_field name =
  string_field name
  |> Decode.and_then (fun s ->
         Decode.from_result
           (Hour_clock.parse s
           |> Result.map_error (fun _ -> Printf.sprintf "%s: expected H:MM:SS.mmm but got \"%s\"" name s)))

let parse_improvement name s =
  match s with
  | "0" -> Ok No_improvement
  | "1" -> Ok Driver_best
  | "2" -> Ok Car_best
  | "3" -> Ok Overall_best
  | _ -> Error (Printf.sprintf "%s: expected 0/1/2/3 but got \"%s\"" name s)

let improvement_field name =
  string_field name |> Decode.and_then (fun s -> Decode.from_result (parse_improvement name s))

let box_field name =
  string_field name
  |> Decode.and_then (fun s ->
         match s with
         | "B" -> Decode.succeed true
         | "" -> Decode.succeed false
         | _ -> Decode.fail (Printf.sprintf "%s: expected \"B\" or blank but got \"%s\"" name s))

let parse_flag name s =
  match s with
  | "GF" -> Ok Green
  | "SF" -> Ok Slow_zone
  | "FCY" -> Ok Full_course_yellow
  | "FF" -> Ok Finish
  | "RF" -> Ok Red
  | _ -> Error (Printf.sprintf "%s: expected GF/SF/FCY/FF/RF but got \"%s\"" name s)

let flag_field name = string_field name |> Decode.and_then (fun s -> Decode.from_result (parse_flag name s))

(* The JVM's rint, which Flix rounds with: a halfway case goes to the even
   neighbour, where OCaml's [Float.round] goes away from zero. *)
let round_half_to_even f =
  let rounded = Float.round f in
  if Float.abs (f -. Float.trunc f) = 0.5 && Float.rem rounded 2.0 <> 0.0 then rounded -. Float.copy_sign 1.0 f
  else rounded

let seconds_to_millis name raw =
  if raw = "" then Ok None
  else
    match Util_parse.float_of_string_opt raw with
    | Some f ->
      let ms = round_half_to_even (f *. 1000.0) in
      if Float.abs ms <= 2147483647.0 then Ok (Some (Duration.of_millis (int_of_float ms)))
      else Error (Printf.sprintf "%s: seconds out of range \"%s\"" name raw)
    | None -> Error (Printf.sprintf "%s: expected seconds but got \"%s\"" name raw)

let show_optional_duration = function Some d -> "Some(" ^ Duration.format d ^ ")" | None -> "None"

let check_sector_consistency name value_ms large_ms seconds_raw improvement =
  match seconds_to_millis name seconds_raw with
  | Error e -> Error e
  | Ok seconds_ms -> (
    let observed = List.filter_map Fun.id [ value_ms; large_ms; seconds_ms ] in
    match observed with
    | [] -> Ok { value = value_ms; improvement }
    | first :: rest ->
      if List.for_all (fun x -> x = first) rest then Ok { value = value_ms; improvement }
      else
        Error
          (Printf.sprintf "%s: value/large/seconds disagree (value=%s, large=%s, seconds=%s)" name
             (show_optional_duration value_ms) (show_optional_duration large_ms) (show_optional_duration seconds_ms)))

let sector_decoder name large_name seconds_name improvement_name =
  Decode.into_record (fun value large seconds improvement -> (value, large, seconds, improvement))
  |> Decode.pipeline (optional_duration_field name)
  |> Decode.pipeline (optional_duration_field large_name)
  |> Decode.pipeline (string_field seconds_name)
  |> Decode.pipeline (improvement_field improvement_name)
  |> Decode.and_then (fun (value, large, seconds, improvement) ->
         Decode.from_result (check_sector_consistency name value large seconds improvement))

let car_decoder () =
  Decode.into_record (fun car_number class_ group team manufacturer ->
      { car_number; class_; group; team; manufacturer })
  |> Decode.pipeline (string_field "NUMBER")
  |> Decode.pipeline (string_field "CLASS")
  |> Decode.pipeline (string_field "GROUP")
  |> Decode.pipeline (string_field "TEAM")
  |> Decode.pipeline (string_field "MANUFACTURER")

let driver_decoder () =
  Decode.into_record (fun number name -> { number; name })
  |> Decode.pipeline (int_field "DRIVER_NUMBER")
  |> Decode.pipeline (string_field "DRIVER_NAME")

(** Both "header missing" and "blank value" map to [None]. *)
let optional_duration_from_optional_column name =
  Decode.map Option.join (Decode.optional_field name (optional_duration_field name))

let mini_sector_decoder id =
  let prefix = Mini_sector.csv_name id in
  Decode.map2
    (fun time mini_elapsed -> { time; mini_elapsed })
    (optional_duration_from_optional_column (prefix ^ "_time"))
    (optional_duration_from_optional_column (prefix ^ "_elapsed"))

let decode_mini_sector_list ids =
  Extra.traverse (fun id -> Decode.map (fun sector -> (id, sector)) (mini_sector_decoder id)) ids

let collapse_if_all_none list =
  let has_any = List.exists (fun (_, sector) -> sector.time <> None || sector.mini_elapsed <> None) list in
  if has_any then Some list else None

(** Decodes the 15 Le Mans mini-sectors. Missing columns (non-Le Mans CSVs) and
    blank values both decode to [None]; an all-[None] row collapses to [None] so
    [to_json] can omit the [miniSectors] key. *)
let mini_sectors_decoder () = Decode.map collapse_if_all_none (decode_mini_sector_list Mini_sector.all)

let decoder () =
  Decode.into_record
    (fun car driver lap_number lap_time lap_improvement crossing_finish_line_in_pit s1 s2 s3 kph elapsed hour top_speed
         pit_time flag_at_fl mini_sectors ->
      {
        car;
        driver;
        lap_number;
        lap_time;
        lap_improvement;
        crossing_finish_line_in_pit;
        s1;
        s2;
        s3;
        kph;
        elapsed;
        hour;
        top_speed;
        pit_time;
        flag_at_fl;
        mini_sectors;
      })
  |> Decode.pipeline (car_decoder ())
  |> Decode.pipeline (driver_decoder ())
  |> Decode.pipeline (int_field "LAP_NUMBER")
  |> Decode.pipeline (duration_field "LAP_TIME")
  |> Decode.pipeline (improvement_field "LAP_IMPROVEMENT")
  |> Decode.pipeline (box_field "CROSSING_FINISH_LINE_IN_PIT")
  |> Decode.pipeline (sector_decoder "S1" "S1_LARGE" "S1_SECONDS" "S1_IMPROVEMENT")
  |> Decode.pipeline (sector_decoder "S2" "S2_LARGE" "S2_SECONDS" "S2_IMPROVEMENT")
  |> Decode.pipeline (sector_decoder "S3" "S3_LARGE" "S3_SECONDS" "S3_IMPROVEMENT")
  |> Decode.pipeline (numeric_string_field "KPH")
  |> Decode.pipeline (duration_field "ELAPSED")
  |> Decode.pipeline (hour_field "HOUR")
  |> Decode.pipeline (numeric_or_blank_string_field "TOP_SPEED")
  |> Decode.pipeline (optional_duration_field "PIT_TIME")
  |> Decode.pipeline (flag_field "FLAG_AT_FL")
  |> Decode.pipeline (mini_sectors_decoder ())

let improvement_to_int = function
  | No_improvement -> 0
  | Driver_best -> 1
  | Car_best -> 2
  | Overall_best -> 3

let box_to_string b = if b then "B" else ""

let flag_to_string = function
  | Green -> "GF"
  | Slow_zone -> "SF"
  | Full_course_yellow -> "FCY"
  | Finish -> "FF"
  | Red -> "RF"

let optional_duration_json = function Some ms -> Json_string (Duration.format ms) | None -> Json_string ""

let sector_to_json (sector : raw_sector) =
  Json_object
    [ ("time", optional_duration_json sector.value); ("improvement", Json_int (improvement_to_int sector.improvement)) ]

let sectors_to_json (raw_lap : raw_lap) =
  Json_object
    [ ("s1", sector_to_json raw_lap.s1); ("s2", sector_to_json raw_lap.s2); ("s3", sector_to_json raw_lap.s3) ]

let lap_to_json (raw_lap : raw_lap) =
  Json_object
    [
      ("time", Json_string (Duration.format raw_lap.lap_time));
      ("improvement", Json_int (improvement_to_int raw_lap.lap_improvement));
    ]

let mini_sector_to_json (sector : raw_mini_sector) =
  Json_object [ ("time", optional_duration_json sector.time); ("elapsed", optional_duration_json sector.mini_elapsed) ]

let mini_sectors_to_json list =
  Json_object
    (List.filter_map
       (fun (id, sector) ->
         if sector.time = None && sector.mini_elapsed = None then None
         else Some (Mini_sector.json_key id, mini_sector_to_json sector))
       list)

let to_json (raw_lap : raw_lap) =
  let leading_fields =
    [
      ("carNumber", Json_string raw_lap.car.car_number);
      ("lapNumber", Json_int raw_lap.lap_number);
      ("driverName", Json_string raw_lap.driver.name);
      ("lap", lap_to_json raw_lap);
      ("sectors", sectors_to_json raw_lap);
    ]
  in
  let mini_fields =
    match raw_lap.mini_sectors with None -> [] | Some list -> [ ("miniSectors", mini_sectors_to_json list) ]
  in
  let trailing_fields =
    [
      ("elapsed", Json_string (Duration.format raw_lap.elapsed));
      ("hour", Json_string (Hour_clock.format raw_lap.hour));
      ("kph", Json_string raw_lap.kph);
      ("topSpeed", Json_string raw_lap.top_speed);
      ("crossingFinishLineInPit", Json_string (box_to_string raw_lap.crossing_finish_line_in_pit));
      ("pitTime", optional_duration_json raw_lap.pit_time);
      ("flagAtFl", Json_string (flag_to_string raw_lap.flag_at_fl));
    ]
  in
  Json_object (leading_fields @ mini_fields @ trailing_fields)
