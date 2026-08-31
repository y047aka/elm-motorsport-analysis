(** Which way round a circuit the cars go. Mirrors [Motorsport.Circuit.Direction]
    on the Elm side. *)

type t =
  | Clockwise
  | Counter_clockwise

let json_value = function Clockwise -> "clockwise" | Counter_clockwise -> "counter_clockwise"
