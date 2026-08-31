(** Extensions to [Util_csv_decode] that go beyond the upstream
    BrianHicks/elm-csv [Csv.Decode] API. Kept in a separate module so the core
    stays a faithful port; reach for these only when the vanilla combinators
    don't compose cleanly. *)

(** Apply a decoder-producing function to every element of a list and collect the
    results into a single list-valued decoder. Equivalent to [sequence . map f];
    failures accumulate via [map2] rather than short-circuiting (mirrors
    [pipeline]).

    Prefer this over nested [and_then] when the per-element decoders are
    independent: [and_then] rebuilds them per row, whereas [traverse] builds the
    decoder graph once. *)
let traverse f list =
  List.fold_right (fun x acc -> Util_csv_decode.map2 (fun b bs -> b :: bs) (f x) acc) list (Util_csv_decode.succeed [])
