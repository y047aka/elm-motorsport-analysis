(** The three sectors every WEC circuit is timed to -- the counterpart of
    [Motorsport_mini_sector] at the coarser grain, and the mirror of
    [Motorsport.Sector] on the Elm side.

    The raw lap spells its sector columns out flat as [s1]/[s2]/[s3]; this type
    is what lets one fold run over all three. *)

type t =
  | S1
  | S2
  | S3

(** In the order a car drives them. *)
let all = [ S1; S2; S3 ]

(** JSON object key, matching the field names of the Elm [BySector]. *)
let json_key = function S1 -> "s1" | S2 -> "s2" | S3 -> "s3"
