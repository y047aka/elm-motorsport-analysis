(** Type-safe CSV decoders, modelled after BrianHicks/elm-csv's [Csv.Decode]
    module. Converts a parsed CSV row (a [string list]) into a value of an
    arbitrary type via a small combinator language.

    Declaration order mirrors the original [Csv.Decode] Elm module (BASIC
    DECODERS / LOCATIONS / RUN DECODERS / MAPPING / FANCY DECODING) so the two
    implementations can be reviewed side by side. *)

module String_map = Map.Make (String)

(* ===== BASIC DECODERS ===== *)

type location =
  | Column_ of int
  | Field_ of string
  | Only_column_

type resolved_names = {
  names : int String_map.t;
  available : bool;
}

(** Where did the problem happen?

    - [Column n]: at the given column number.
    - [Field (name, maybe_col)]: at the given named column (with optional column
      number).
    - [Only_column]: at the only column in the row. *)
type column =
  | Column of int
  | Field of string * int option
  | Only_column

(** Things that can go wrong while decoding.

    - [Column_not_found n]: column [n] does not exist.
    - [Field_not_found name]: column [name] exists in headers but not in this row.
    - [Expected_one_column n]: basic decoders need exactly one column; found [n].
    - [Expected_int s] / [Expected_float s]: failed to parse a number.
    - [Failure msg]: custom failure from [fail]. *)
type problem =
  | Column_not_found of int
  | Field_not_found of string
  | Expected_one_column of int
  | Expected_int of string
  | Expected_float of string
  | Failure of string

(** Errors when decoding a single row.

    - [Field_decoding_error (row, column, problem)]: a specific field failed.
    - [One_of_decoding_error (row, errors)]: all branches of [one_of] failed.
    - [Field_not_provided name]: the named column was not in the header.
    - [No_field_names_provided]: [available_fields] used with [No_field_names]. *)
type decoding_error =
  | Field_decoding_error of int * column * problem
  | One_of_decoding_error of int * decoding_error list
  | Field_not_provided of string
  | No_field_names_provided

(** Errors that can occur while decoding a CSV.

    - [Parsing_error]: a problem parsing the CSV into rows and columns (quoting
      issues).
    - [No_field_names_on_first_row]: tried to get field names from the first row
      but found none.
    - [Decoding_errors]: one or more rows failed to decode. *)
type error =
  | Parsing_error of Util_csv_parser.problem
  | No_field_names_on_first_row
  | Decoding_errors of decoding_error list

type 'a decoder = Decoder of (location -> resolved_names -> int -> string list -> ('a, decoding_error list) result)

let location_to_column field_names location =
  match location with
  | Column_ i -> Column i
  | Field_ name -> Field (name, String_map.find_opt name field_names)
  | Only_column_ -> Only_column

let from_string convert =
  Decoder
    (fun location field_names row_num row ->
      let error problem = Error [ Field_decoding_error (row_num, location_to_column field_names.names location, problem) ] in
      let converted value = match convert value with Ok c -> Ok c | Error problem -> error problem in
      match location with
      | Column_ col_num -> (
        match List.nth_opt row col_num with Some value -> converted value | None -> error (Column_not_found col_num))
      | Field_ name -> (
        match String_map.find_opt name field_names.names with
        | Some col_num -> (
          match List.nth_opt row col_num with Some value -> converted value | None -> error (Field_not_found name))
        | None -> Error [ Field_not_provided name ])
      | Only_column_ -> (
        match row with
        | [] -> error (Column_not_found 0)
        | [ only ] -> converted only
        | _ -> error (Expected_one_column (List.length row))))

(** Decode a string. *)
let string () = from_string (fun s -> Ok s)

(** Decode an integer. *)
let int () =
  from_string (fun value ->
      match Util_parse.int_of_string_opt (String.trim value) with
      | Some parsed -> Ok parsed
      | None -> Error (Expected_int value))

(** Decode a floating-point number. *)
let float () =
  from_string (fun value ->
      match Util_parse.float_of_string_opt (String.trim value) with
      | Some parsed -> Ok parsed
      | None -> Error (Expected_float value))

(* ===== MAPPING (defined early: `blank` builds on it) ===== *)

(** Transform a decoded value. *)
let map transform (Decoder decode) =
  Decoder (fun location field_names row_num row -> Result.map transform (decode location field_names row_num row))

(** Combine two decoders to make something else. *)
let map2 transform (Decoder decode_a) (Decoder decode_b) =
  Decoder
    (fun location field_names row_num row ->
      match (decode_a location field_names row_num row, decode_b location field_names row_num row) with
      | Ok a, Ok b -> Ok (transform a b)
      | Error a, Error b -> Error (a @ b)
      | Error a, _ -> Error a
      | _, Error b -> Error b)

(** Like [map2], but with three decoders. Use [into_record] for more fields. *)
let map3 transform (Decoder decode_a) (Decoder decode_b) (Decoder decode_c) =
  Decoder
    (fun location field_names row_num row ->
      match
        ( decode_a location field_names row_num row,
          decode_b location field_names row_num row,
          decode_c location field_names row_num row )
      with
      | Ok a, Ok b, Ok c -> Ok (transform a b c)
      | Error a, Error b, Error c -> Error (a @ b @ c)
      | Error a, Error b, _ -> Error (a @ b)
      | _, Error b, Error c -> Error (b @ c)
      | Error a, _, Error c -> Error (a @ c)
      | _, _, Error c -> Error c
      | _, Error b, _ -> Error b
      | Error a, _, _ -> Error a)

(** Decode some value and then make a decoding decision based on the outcome. *)
let and_then next (Decoder decode_first) =
  Decoder
    (fun location field_names row_num row ->
      Result.bind (decode_first location field_names row_num row) (fun next_value ->
          let (Decoder decode_final) = next next_value in
          decode_final location field_names row_num row))

(** Always succeed, no matter what. Mostly useful with [and_then]. *)
let succeed value = Decoder (fun _ _ _ _ -> Ok value)

(** Handle blank fields by turning them into options. We consider a field to be
    blank if it's empty or consists solely of whitespace characters. *)
let blank decoder =
  let is_unicode_whitespace cp =
    List.mem cp [ 0x09; 0x0A; 0x0B; 0x0C; 0x0D; 0x1C; 0x1D; 0x1E; 0x1F; 0x20 ]
    || cp = 0x00A0 || cp = 0x2007 || cp = 0x202F || cp = 0x1680
    || (cp >= 0x2000 && cp <= 0x200A)
    || cp = 0x2028 || cp = 0x2029 || cp = 0x205F || cp = 0x3000
  in
  let all_whitespace s =
    let rec go i =
      if i >= String.length s then true
      else
        let decoded = String.get_utf_8_uchar s i in
        Uchar.utf_decode_is_valid decoded
        && is_unicode_whitespace (Uchar.to_int (Uchar.utf_decode_uchar decoded))
        && go (i + Uchar.utf_decode_length decoded)
    in
    go 0
  in
  and_then (fun maybe_blank -> if all_whitespace maybe_blank then succeed None else map Option.some decoder) (string ())

(* ===== LOCATIONS ===== *)

(** Parse a value at a numbered column, starting from 0. *)
let column col (Decoder decode) =
  Decoder (fun _ field_names row_num row -> decode (Column_ col) field_names row_num row)

(** Like [column], but succeeds even if the column is missing. *)
let optional_column col (Decoder decode) =
  Decoder
    (fun _ field_names row_num row ->
      if col < List.length row then Result.map Option.some (decode (Column_ col) field_names row_num row) else Ok None)

(** Parse a value at a named column. *)
let field name (Decoder decode) =
  Decoder (fun _ field_names row_num row -> decode (Field_ name) field_names row_num row)

(** Like [field], but succeeds even if the column is missing. *)
let optional_field name (Decoder decode) =
  Decoder
    (fun _ field_names row_num row ->
      match String_map.find_opt name field_names.names with
      | Some _ -> Result.map Option.some (decode (Field_ name) field_names row_num row)
      | None -> Ok None)

(** Returns all available field names. The behavior depends on your
    configuration:

    - [No_field_names]: the decoder fails.
    - [Custom_field_names]: decodes to the provided list.
    - [Field_names_from_first_row]: returns the first row of the CSV. *)
let available_fields () =
  Decoder
    (fun _ field_names _ _ ->
      if field_names.available then
        Ok
          (String_map.bindings field_names.names
          |> List.stable_sort (fun (_, a) (_, b) -> compare a b)
          |> List.map fst)
      else Error [ No_field_names_provided ])

(* ===== RUN DECODERS ===== *)

(** Where do we get names for use with [field]?

    - [No_field_names]: don't get field names at all. [field] will always fail.
    - [Custom_field_names]: use the provided field names in order.
    - [Field_names_from_first_row]: use the first row of the CSV as field names. *)
type field_names =
  | No_field_names
  | Custom_field_names of string list
  | Field_names_from_first_row

let get_field_names headers rows =
  let from_list names =
    fst (List.fold_left (fun (so_far, i) name -> (String_map.add name i so_far, i + 1)) (String_map.empty, 0) names)
  in
  match headers with
  | No_field_names -> Ok ({ names = String_map.empty; available = false }, 0, rows)
  | Custom_field_names names -> Ok ({ names = from_list names; available = true }, 0, rows)
  | Field_names_from_first_row -> (
    match rows with
    | [] -> Error No_field_names_on_first_row
    | first :: rest -> Ok ({ names = from_list (List.map String.trim first); available = true }, 1, rest))

let apply_decoder field_names (Decoder decode) all_rows =
  let default_location = Only_column_ in
  Result.bind (get_field_names field_names all_rows) (fun (resolved_names, first_row_number, rows) ->
      let result, _ =
        List.fold_left
          (fun (so_far, row_num) row ->
            let new_so_far =
              match decode default_location resolved_names row_num row with
              | Ok value -> ( match so_far with Ok values -> Ok (value :: values) | Error errs -> Error errs)
              | Error err -> ( match so_far with Ok _ -> Error [ err ] | Error errs -> Error (err :: errs))
            in
            (new_so_far, row_num + 1))
          (Ok [], first_row_number) rows
      in
      result |> Result.map List.rev |> Result.map_error (fun errs -> Decoding_errors (List.concat (List.rev errs))))

(** Convert something shaped roughly like a CSV (e.g. TSV with
    [~field_separator:'\t']). *)
let decode_custom ~field_separator field_names decoder source =
  Util_csv_parser.parse ~field_separator source
  |> Result.map_error (fun p -> Parsing_error p)
  |> fun parsed -> Result.bind parsed (apply_decoder field_names decoder)

(** Convert a CSV string into some type you care about using the decoders in this
    module. *)
let decode_csv field_names decoder source = decode_custom ~field_separator:',' field_names decoder source

(** Produce a human-readable version of an [error]. *)
let error_to_string error =
  match error with
  | Parsing_error (Util_csv_parser.Source_ended_without_closing_quote row) ->
    Printf.sprintf "The source ended on row %d in a quoted field without a closing quote." row
  | Parsing_error (Util_csv_parser.Additional_characters_after_closing_quote row) ->
    Printf.sprintf "On row %d in the source, there were additional characters in a field after a closing quote." row
  | No_field_names_on_first_row -> "I expected to see field names on the first row, but there were none."
  | Decoding_errors errs ->
    let problem_string = function
      | Column_not_found i -> Printf.sprintf "I couldn't find column #%d." i
      | Field_not_found name -> Printf.sprintf "I couldn't find the `%s` column." name
      | Expected_one_column n -> Printf.sprintf "I expected exactly one column, but there were %d." n
      | Expected_int not_int -> Printf.sprintf "I could not parse an int from `%s`." not_int
      | Expected_float not_float -> Printf.sprintf "I could not parse a float from `%s`." not_float
      | Failure custom -> custom
    in
    let column_string = function
      | Column c -> Printf.sprintf "column %d" c
      | Field (name, None) -> Printf.sprintf "in the `%s` field" name
      | Field (name, Some c) -> Printf.sprintf "in the `%s` field (column %d)" name c
      | Only_column -> "column 0 (the only column present)"
    in
    let row_string start_row end_row =
      match end_row - start_row with
      | 0 -> Printf.sprintf "row %d" start_row
      | 1 -> Printf.sprintf "rows %d and %d" start_row end_row
      | _ -> Printf.sprintf "rows %d\xe2\x80\x93%d" start_row end_row
    in
    let rec err_string = function
      | Field_decoding_error (_, col, problem) -> column_string col ^ ": " ^ problem_string problem
      | One_of_decoding_error (_, oodes) ->
        "all of the following decoders failed, but at least one must succeed:\n"
        ^ String.concat "\n" (List.mapi (fun i e -> Printf.sprintf "  (%d) %s" (i + 1) (err_string e)) oodes)
      | Field_not_provided name -> Printf.sprintf "field %s was not provided" name
      | No_field_names_provided -> "Asked for available fields, but none were provided"
    in
    let top_level_err_string start_row end_row err =
      (match err with
      | Field_decoding_error _ -> "There was a problem on " ^ row_string start_row end_row ^ ", "
      | One_of_decoding_error _ -> "There was a problem on " ^ row_string start_row end_row ^ " - "
      | Field_not_provided _ -> "There was a problem in the header: "
      | No_field_names_provided -> "")
      ^ err_string err
    in
    let rec is_contiguous err_a err_b =
      match (err_a, err_b) with
      | Field_decoding_error (a_row, a_col, a_problem), Field_decoding_error (b_row, b_col, b_problem) ->
        a_problem = b_problem && a_row + 1 = b_row && a_col = b_col
      | One_of_decoding_error (a_row, a_list), One_of_decoding_error (b_row, b_list) ->
        a_row + 1 = b_row
        && List.length a_list = List.length b_list
        && List.for_all2 is_contiguous a_list b_list
      | _ -> err_a = err_b
    in
    let get_row = function
      | Field_decoding_error (row, _, _) -> row
      | One_of_decoding_error (row, _) -> row
      | Field_not_provided _ -> 0
      | No_field_names_provided -> 0
    in
    let close head tail = match List.rev tail with start_err :: _ -> start_err | [] -> head in
    let rec dedupe_help so_far prev_group errors =
      match (errors, prev_group) with
      | [], [] -> List.rev so_far
      | [], head :: tail -> List.rev ((get_row (close head tail), get_row head, head) :: so_far)
      | err :: rest, [] -> dedupe_help so_far [ err ] rest
      | err :: rest, head :: tail ->
        if is_contiguous head err then dedupe_help so_far (err :: prev_group) rest
        else dedupe_help ((get_row (close head tail), get_row head, head) :: so_far) [ err ] rest
    in
    let sort_key = function
      | Field_decoding_error (row, _, problem) -> (
        match problem with
        | Column_not_found _ -> (1, "", row)
        | Field_not_found name -> (2, name, row)
        | Expected_one_column n -> (3, string_of_int n, row)
        | Expected_int s -> (4, s, row)
        | Expected_float s -> (5, s, row)
        | Failure s -> (6, s, row))
      (* Not completely foolproof when multiple One_of errors per row share the
         same branch count. *)
      | One_of_decoding_error (row, list) -> (7, string_of_int (List.length list), row)
      | Field_not_provided name -> (8, name, 0)
      | No_field_names_provided -> (9, "", 0)
    in
    let dedupe_errs es =
      es
      |> List.stable_sort (fun a b -> compare (sort_key a) (sort_key b))
      |> dedupe_help [] []
      |> List.stable_sort (fun (start_a, _, err_a) (start_b, _, err_b) ->
             compare (start_a, sort_key err_a) (start_b, sort_key err_b))
    in
    (match dedupe_errs errs with
    | [] -> "Something went wrong, but I got an blank error list so I don't know what it was. Please open an issue!"
    | [ (start_row, end_row, err) ] -> top_level_err_string start_row end_row err
    | multiple ->
      Printf.sprintf "I saw %d problems while decoding this CSV:\n\n" (List.length multiple)
      ^ String.concat "\n\n" (List.map (fun (start_row, end_row, err) -> top_level_err_string start_row end_row err) multiple))

(** Combine an arbitrary number of fields. Provide a curried function, then
    supply each argument with [pipeline]. *)
let into_record f = succeed f

(** See [into_record]. *)
let pipeline decoder decoder_fn = map2 (fun value fn -> fn value) decoder decoder_fn

(* ===== FANCY DECODING ===== *)

let recover (Decoder decode_first) (Decoder decode_second) =
  Decoder
    (fun location field_names row_num row ->
      match decode_first location field_names row_num row with
      | Ok value -> Ok value
      | Error errs -> (
        match decode_second location field_names row_num row with
        | Ok value -> Ok value
        | Error [ One_of_decoding_error (_, problems) ] -> Error [ One_of_decoding_error (row_num, errs @ problems) ]
        | Error problems -> Error [ One_of_decoding_error (row_num, errs @ problems) ]))

(** Try several possible decoders in sequence, committing to the first one that
    passes. *)
let rec one_of first rest =
  match rest with [] -> first | next :: others -> recover first (one_of next others)

(** Always fail with the given message, no matter what. Mostly useful with
    [and_then]. *)
let fail message =
  Decoder
    (fun location field_names row_num _ ->
      Error [ Field_decoding_error (row_num, location_to_column field_names.names location, Failure message) ])

(** Make creating custom decoders a little easier. *)
let from_result result = match result with Ok value -> succeed value | Error problem -> fail problem

(** Like [from_result] but you supply the error message since [None] has no
    information. *)
let from_option problem option = match option with Some value -> succeed value | None -> fail problem
