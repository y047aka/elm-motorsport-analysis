module Decode = Util_csv_decode

let byte_order_mark = "\xef\xbb\xbf"

(** Strips a leading UTF-8 BOM (U+FEFF) emitted by some Windows tools before
    handing the text to the decoder. *)
let decode input_path content =
  let width = String.length byte_order_mark in
  let stripped =
    if String.length content >= width && String.sub content 0 width = byte_order_mark then
      String.sub content width (String.length content - width)
    else content
  in
  Decode.decode_custom ~field_separator:';' Decode.Field_names_from_first_row (Motorsport_wec.decoder ()) stripped
  |> Result.map_error (fun e -> Cli_errors.Csv { path = input_path; message = Decode.error_to_string e })
