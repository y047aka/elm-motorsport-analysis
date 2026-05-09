/// Extensions to `Util.Csv.Decode` that go beyond the upstream
/// BrianHicks/elm-csv `Csv.Decode` API. Kept in a separate module so
/// the core stays a faithful port; reach for these only when the
/// vanilla combinators don't compose cleanly.
mod Util.Csv.Decode.Extra {

    use Util.Csv.Decode.Decoder

    /// Apply a decoder-producing function to every element of a list and
    /// collect the results into a single list-valued decoder. Equivalent
    /// to `sequence . map f`; failures accumulate via `map2` rather than
    /// short-circuiting (mirrors `pipeline`).
    ///
    /// Prefer this over nested `andThen` when the per-element decoders are
    /// independent: `andThen` rebuilds them per row, whereas `traverse`
    /// builds the decoder graph once.
    pub def traverse(f: a -> Decoder[b], list: List[a]): Decoder[List[b]] =
        List.foldRight(
            (x, acc) -> Util.Csv.Decode.map2((b, bs) -> b :: bs, f(x), acc),
            Util.Csv.Decode.succeed(Nil),
            list
        )

}
