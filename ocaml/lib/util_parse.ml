(** Number parsing with the semantics Flix gets from its standard library:
    [Int32.fromString] and [Float64.fromString] are Java's [Integer.parseInt] and
    [Double.parseDouble], which reject the underscores, [0x] literals and other
    OCaml spellings that [int_of_string_opt] and [float_of_string_opt] accept. *)

let is_digit c = c >= '0' && c <= '9'

let body s = if String.length s > 0 && (s.[0] = '+' || s.[0] = '-') then String.sub s 1 (String.length s - 1) else s

let all_digits s = s <> "" && String.for_all is_digit s

let int_of_string_opt s = if all_digits (body s) then int_of_string_opt s else None

(** Accepts what Java writes back out: a decimal or scientific literal, the
    [f]/[d] suffix its own [Double.toString] never emits but [parseDouble] takes,
    and the two names that are not numbers at all. *)
let float_of_string_opt s =
  let s = String.trim s in
  let named = List.mem s [ "NaN"; "Infinity"; "+Infinity"; "-Infinity" ] in
  let decimal s =
    let mantissa, exponent =
      match String.index_opt s 'e', String.index_opt s 'E' with
      | Some i, _ | None, Some i -> String.sub s 0 i, Some (String.sub s (i + 1) (String.length s - i - 1))
      | None, None -> s, None
    in
    let exponent_ok = match exponent with None -> true | Some e -> all_digits (body e) in
    let mantissa_ok =
      match String.split_on_char '.' (body mantissa) with
      | [ whole ] -> all_digits whole
      | [ whole; fraction ] ->
        (whole = "" || all_digits whole) && (fraction = "" || all_digits fraction) && whole ^ fraction <> ""
      | _ -> false
    in
    mantissa_ok && exponent_ok
  in
  let suffixless =
    let n = String.length s in
    if n > 1 && List.mem s.[n - 1] [ 'f'; 'F'; 'd'; 'D' ] then String.sub s 0 (n - 1) else s
  in
  if named || decimal suffixless then float_of_string_opt suffixless else None

(** Flix's [String.split] is Java's, which drops the empty pieces a trailing
    separator leaves -- so [0:] splits to one field, not two, and a duration
    written without its seconds still reads as a duration. OCaml's
    [String.split_on_char] keeps them, which turns the same text into a parse
    failure. *)
let split_on_char separator s =
  if not (String.contains s separator) then [ s ]
  else
    let rec drop_trailing = function "" :: rest -> drop_trailing rest | l -> l in
    List.rev (drop_trailing (List.rev (String.split_on_char separator s)))
