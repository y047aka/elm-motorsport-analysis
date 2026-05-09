/// Extensions to `Util.Csv.Decode` that go beyond the upstream
/// BrianHicks/elm-csv `Csv.Decode` API. Kept in a separate module so
/// the core stays a faithful port; reach for these only when the
/// vanilla combinators don't compose cleanly.
mod Util.Csv.Decode.Extra {

    use Util.Csv.Decode.Decoder

    /// Apply a decoder-producing function to every element of a list and
    /// collect the results into a single list-valued decoder.
    ///
    /// Equivalent to `sequence . map f` in Haskell-style notation. The
    /// produced decoder applies each per-element decoder to the same row
    /// in list order; failures accumulate via the underlying `map2`
    /// rather than short-circuiting (mirrors `pipeline`).
    ///
    /// Prefer this over `List.foldRight` with nested `andThen` when the
    /// per-element decoders are independent: `andThen` rebuilds inner
    /// decoders on every row (because the continuation `next(value)` is
    /// invoked per-row), whereas `traverse` builds the full decoder
    /// graph once at construction time and only walks it per row.
    pub def traverse(f: a -> Decoder[b], list: List[a]): Decoder[List[b]] =
        List.foldRight(
            (x, acc) -> Util.Csv.Decode.map2((b, bs) -> b :: bs, f(x), acc),
            Util.Csv.Decode.succeed(Nil),
            list
        )

}
