(** Le Mans 24h mini-sectors. The 15 named segments live alongside the standard
    S1/S2/S3 split and only appear in the Le Mans CSV; other WEC rounds omit
    these columns entirely. This module is the single source of truth for the
    IDs, their CSV column prefixes, and their JSON object keys, mirroring
    [Motorsport.Wec.Circuit.LeMans.all] on the Elm side. *)

type t =
  | SCL2
  | Z4
  | IP1
  | Z12
  | SCLC
  | A7_1
  | IP2
  | A8_1
  | SCLB
  | PORIN
  | POROUT
  | PITREF
  | SCL1
  | FORDOUT
  | FL

(** Track-order list -- must match [Motorsport.Wec.Circuit.LeMans.all]. Line
    groups correspond to S1 / S2 / S3. *)
let all =
  [ SCL2; Z4; IP1; Z12; SCLC; A7_1; IP2; A8_1; SCLB; PORIN; POROUT; PITREF; SCL1; FORDOUT; FL ]

(** The line groups of [all] written out. Total by construction, so a
    mini-sector cannot go missing from the grouping or land in two sectors. *)
let sector_of id =
  let open Motorsport_sector in
  match id with
  | SCL2 -> S1
  | Z4 -> S1
  | IP1 -> S1
  | Z12 -> S2
  | SCLC -> S2
  | A7_1 -> S2
  | IP2 -> S2
  | A8_1 -> S3
  | SCLB -> S3
  | PORIN -> S3
  | POROUT -> S3
  | PITREF -> S3
  | SCL1 -> S3
  | FORDOUT -> S3
  | FL -> S3

(** CSV column prefix. A7_1 / A8_1 map to the hyphenated [A7-1] / [A8-1] (the
    constructor underscore is a syntax constraint, not part of the column name).
    Each prefix yields two columns: [_time] and [_elapsed]. *)
let csv_name = function
  | SCL2 -> "SCL2"
  | Z4 -> "Z4"
  | IP1 -> "IP1"
  | Z12 -> "Z12"
  | SCLC -> "SCLC"
  | A7_1 -> "A7-1"
  | IP2 -> "IP2"
  | A8_1 -> "A8-1"
  | SCLB -> "SCLB"
  | PORIN -> "PORIN"
  | POROUT -> "POROUT"
  | PITREF -> "PITREF"
  | SCL1 -> "SCL1"
  | FORDOUT -> "FORDOUT"
  | FL -> "FL"

(** JSON object key -- lower-case [csv_name] with the hyphen reverted to an
    underscore (matches the Elm [Motorsport.Lap.MiniSectors] field names). *)
let json_key = function
  | SCL2 -> "scl2"
  | Z4 -> "z4"
  | IP1 -> "ip1"
  | Z12 -> "z12"
  | SCLC -> "sclc"
  | A7_1 -> "a7_1"
  | IP2 -> "ip2"
  | A8_1 -> "a8_1"
  | SCLB -> "sclb"
  | PORIN -> "porin"
  | POROUT -> "porout"
  | PITREF -> "pitref"
  | SCL1 -> "scl1"
  | FORDOUT -> "fordout"
  | FL -> "fl"

(** True when [blanks] matches one of the known Ford-chicane track-limits
    signatures observed at Le Mans 2025: [SCL1+FORDOUT] (second chicane) or
    [PITREF+SCL1] (first chicane). Assumes the input is in track order. *)
let is_track_limits_signature blanks = blanks = [ SCL1; FORDOUT ] || blanks = [ PITREF; SCL1 ]
