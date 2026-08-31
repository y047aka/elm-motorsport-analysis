(* The Rust version emits log::warn! (warn_once) for unknown IDs, omitted here to keep this pure. *)

let display_name event_id =
  match event_id with
  | "qatar_1812km" -> "Qatar 1812km"
  | "imola_6h" -> "6 Hours of Imola"
  | "spa_6h" -> "6 Hours of Spa"
  | "le_mans_24h" -> "24 Hours of Le Mans"
  | "cota_6h" -> "Lone Star Le Mans"
  | "fuji_6h" -> "6 Hours of Fuji"
  | "bahrain_8h" -> "8 Hours of Bahrain"
  | "sao_paulo_6h" -> "6 Hours of S\xc3\xa3o Paulo"
  | other -> other

(** [display_name] passes an unrecognized id through, because a name never seen
    before is still the best name there is. A direction has no such answer --
    guessing clockwise would draw the whole field going the wrong way round,
    which reads as data rather than as a gap -- so an id not listed here gets
    none, and the summary leaves the key out.

    Keyed by a string, nothing makes a new round answer. [Test_events] names the
    calendar and asserts each round has a direction, which is what stands in for
    the compiler. *)
let direction event_id =
  let open Motorsport_circuit_direction in
  match event_id with
  | "qatar_1812km" -> Some Clockwise
  | "imola_6h" -> Some Counter_clockwise
  | "spa_6h" -> Some Clockwise
  | "le_mans_24h" -> Some Clockwise
  | "cota_6h" -> Some Counter_clockwise
  | "fuji_6h" -> Some Clockwise
  | "bahrain_8h" -> Some Clockwise
  | "sao_paulo_6h" -> Some Counter_clockwise
  | _ -> None
