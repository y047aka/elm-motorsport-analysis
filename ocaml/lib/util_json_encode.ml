type json_value =
  | Json_null
  | Json_bool of bool
  | Json_int of int
  | Json_float of float
  | Json_string of string
  | Json_array of json_value list
  | Json_object of (string * json_value) list

(** The shortest decimal that reads back as the same double, which is what the
    JVM writes and so what keeps the two CLIs' output comparable. OCaml's own
    [string_of_float] stops at twelve significant digits and loses the last of a
    share's precision. *)
let float_to_string f =
  let shortest =
    let rec try_precision = function
      | [] -> Printf.sprintf "%.17g" f
      | precision :: rest ->
        let rendered = Printf.sprintf "%.*g" precision f in
        if float_of_string rendered = f then rendered else try_precision rest
    in
    try_precision [ 15; 16; 17 ]
  in
  if String.exists (fun c -> c = '.' || c = 'e' || c = 'n' || c = 'i') shortest then shortest else shortest ^ ".0"

let escape_string s =
  let buffer = Buffer.create (String.length s) in
  String.iter
    (fun c ->
      match c with
      | '\\' -> Buffer.add_string buffer "\\\\"
      | '"' -> Buffer.add_string buffer "\\\""
      | '\n' -> Buffer.add_string buffer "\\n"
      | '\r' -> Buffer.add_string buffer "\\r"
      | '\t' -> Buffer.add_string buffer "\\t"
      | c -> Buffer.add_char buffer c)
    s;
  Buffer.contents buffer

let rec render_with_indent indent value =
  let spaces = String.make indent ' ' in
  let inner = String.make (indent + 2) ' ' in
  match value with
  | Json_null -> "null"
  | Json_bool b -> if b then "true" else "false"
  | Json_int n -> string_of_int n
  | Json_float n -> float_to_string n
  | Json_string s -> "\"" ^ escape_string s ^ "\""
  | Json_array [] -> "[]"
  | Json_array xs ->
    let items = List.map (fun x -> inner ^ render_with_indent (indent + 2) x) xs in
    Printf.sprintf "[\n%s\n%s]" (String.concat ",\n" items) spaces
  | Json_object [] -> "{}"
  | Json_object kvs ->
    let entries =
      List.map (fun (k, v) -> Printf.sprintf "%s\"%s\": %s" inner (escape_string k) (render_with_indent (indent + 2) v)) kvs
    in
    Printf.sprintf "{\n%s\n%s}" (String.concat ",\n" entries) spaces

let render value = render_with_indent 0 value
