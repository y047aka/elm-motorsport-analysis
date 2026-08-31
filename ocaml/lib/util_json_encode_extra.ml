(** Rendering that departs from [Util_json_encode.render], which puts every value
    on a line of its own. *)

open Util_json_encode

let key k = Util_json_encode.render (Json_string k)
let inline_object entries = Printf.sprintf "{ %s }" (String.concat ", " entries)
let fits_on_one_line rendered = not (String.contains rendered '\n')

let on_own_lines indent opening items closing =
  let spaces = String.make indent ' ' in
  let inner = String.make (indent + 2) ' ' in
  Printf.sprintf "%s\n%s%s\n%s%s" opening inner (String.concat (",\n" ^ inner) items) spaces closing

let rec render_with_indent indent value =
  match value with
  | Json_array xs -> render_array indent xs
  | Json_object kvs -> render_object indent kvs
  | scalar -> Util_json_encode.render scalar

and render_array indent xs =
  if xs = [] then "[]" else on_own_lines indent "[" (List.map (fun x -> render_with_indent (indent + 2) x) xs) "]"

and render_object indent kvs =
  if kvs = [] then "{}"
  else
    let entries = List.map (fun (k, v) -> Printf.sprintf "%s: %s" (key k) (render_with_indent (indent + 2) v)) kvs in
    if List.length entries <= 2 && List.for_all fits_on_one_line entries then inline_object entries
    else on_own_lines indent "{" entries "}"

(** Renders as [Util_json_encode.render] does, except that an object of at most
    two properties, each of whose values fits on a line, is written inline:

    {v
    { "name": "James CALADO" }
    { "time": "20.708", "elapsed": "20.708" }
    v} *)
let render value = render_with_indent 0 value

(** Renders the whole value on one line, however many properties it holds. For
    JSON Lines output, where the line break separates records and so cannot
    appear inside one. *)
let rec render_on_one_line value =
  match value with
  | Json_array [] -> "[]"
  | Json_array xs -> Printf.sprintf "[%s]" (String.concat ", " (List.map render_on_one_line xs))
  | Json_object [] -> "{}"
  | Json_object kvs ->
    inline_object (List.map (fun (k, v) -> Printf.sprintf "%s: %s" (key k) (render_on_one_line v)) kvs)
  | scalar -> Util_json_encode.render scalar
