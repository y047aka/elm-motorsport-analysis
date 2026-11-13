/// Which layout this project's JSON is written in.
pub mod Util.Json.Extra {

    use oj::OrderedJson
    use oj::OrderedJson.Json
    use oj::OrderedJson.Inline
    use oj::OrderedJson.Style

    /// The two-property limit is what the committed archive froze.
    pub def render(value: Json): String =
        OrderedJson.renderWith(Style.Inlined(Inline.AtMost(2), 2), value)

    /// For JSON Lines output, where the line break separates records and so cannot appear inside one.
    pub def renderOnOneLine(value: Json): String =
        OrderedJson.renderWith(Style.OneLine, value)

}
