(** CSV parser modelled after BrianHicks/elm-csv's [Csv.Parser]. Function names
    and call structure mirror the elm-csv 4.0.1 source so the two
    implementations can be reviewed side by side. *)

(** Something went wrong during parsing! What was it?

    - [Source_ended_without_closing_quote]: we started parsing a quoted field,
      but the file ended before we saw a closing quote. If you meant to have a
      literal quote in your data, quote the whole field and then escape the
      literal quote by doubling it.
    - [Additional_characters_after_closing_quote]: we found the closing pair of a
      quoted field, but there was data after it but before a separator or the end
      of the file. Follow the quote-escaping advice above to get around this. *)

type problem =
  | Source_ended_without_closing_quote of int
  | Additional_characters_after_closing_quote of int

let problem_to_string = function
  | Source_ended_without_closing_quote row -> Printf.sprintf "Source_ended_without_closing_quote(%d)" row
  | Additional_characters_after_closing_quote row ->
    Printf.sprintf "Additional_characters_after_closing_quote(%d)" row

let slice source start_offset end_offset = String.sub source start_offset (end_offset - start_offset)

let rec parse_quoted_field is_field_separator source final_length so_far start_offset end_offset =
  if end_offset >= final_length then Error (fun n -> Source_ended_without_closing_quote n)
  else if source.[end_offset] = '"' then
    let segment = slice source start_offset end_offset in
    if end_offset + 1 >= final_length then Ok (so_far ^ segment, end_offset + 1, false)
    else
      let next = source.[end_offset + 1] in
      if next = '"' then
        (* A doubled quote is an escaped one. Unescape it and keep going. *)
        let new_pos = end_offset + 2 in
        parse_quoted_field is_field_separator source final_length (so_far ^ segment ^ "\"") new_pos new_pos
      else if is_field_separator next then Ok (so_far ^ segment, end_offset + 2, false)
      else if next = '\n' then Ok (so_far ^ segment, end_offset + 2, true)
      else if next = '\r' && end_offset + 2 < final_length && source.[end_offset + 2] = '\n' then
        Ok (so_far ^ segment, end_offset + 3, true)
      else Error (fun n -> Additional_characters_after_closing_quote n)
  else parse_quoted_field is_field_separator source final_length so_far start_offset (end_offset + 1)

let rec parse_help is_field_separator source final_length row rows start_offset end_offset =
  if end_offset >= final_length then
    let final_field = slice source start_offset end_offset in
    if final_field = "" && row = [] then Ok (List.rev rows)
    else Ok (List.rev (List.rev (final_field :: row) :: rows))
  else
    let first = source.[end_offset] in
    if is_field_separator first then
      let new_pos = end_offset + 1 in
      parse_help is_field_separator source final_length (slice source start_offset end_offset :: row) rows new_pos new_pos
    else if first = '\n' then
      let new_pos = end_offset + 1 in
      parse_help is_field_separator source final_length []
        (List.rev (slice source start_offset end_offset :: row) :: rows)
        new_pos new_pos
    else if first = '\r' && end_offset + 1 < final_length && source.[end_offset + 1] = '\n' then
      let new_pos = end_offset + 2 in
      parse_help is_field_separator source final_length []
        (List.rev (slice source start_offset end_offset :: row) :: rows)
        new_pos new_pos
    else if first = '"' then
      let new_pos = end_offset + 1 in
      match parse_quoted_field is_field_separator source final_length "" new_pos new_pos with
      | Ok (value, after_quoted_field, row_ended) ->
        if after_quoted_field >= final_length then Ok (List.rev (List.rev (value :: row) :: rows))
        else if row_ended then
          parse_help is_field_separator source final_length [] (List.rev (value :: row) :: rows) after_quoted_field
            after_quoted_field
        else parse_help is_field_separator source final_length (value :: row) rows after_quoted_field after_quoted_field
      | Error problem -> Error (problem (List.length rows + 1))
    else parse_help is_field_separator source final_length row rows start_offset (end_offset + 1)

(** Turn a CSV string into a list of rows. *)
let parse ~field_separator source =
  if source = "" then Ok []
  else parse_help (fun c -> c = field_separator) source (String.length source) [] [] 0 0
