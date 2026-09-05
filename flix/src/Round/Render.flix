mod Round.Render {

    use Util.Json.Encode.Extra
    use Util.Json.Encode.JsonValue
    use Motorsport.Index
    use Motorsport.Metadata
    use Motorsport.Wec
    use Motorsport.Wec.RawLap

    /// The round's summary and the indices read off the same rows, written as
    /// one document.
    pub def renderSummary(metadata: Metadata.Metadata, index: Index.Index): String =
        Extra.render(withIndex(Metadata.toJson(metadata), Index.toJson(index)))

    def withIndex(metadata: JsonValue, index: JsonValue): JsonValue =
        match metadata {
            case JsonValue.JsonObject(fields) =>
                JsonValue.JsonObject(List.append(fields, ("index", index) :: Nil))
            case other => other
        }

    pub def renderJsonl(rawLaps: List[RawLap]): String =
        rawLaps
            |> List.map(rawLap -> "${Extra.renderOnOneLine(Wec.toJson(rawLap))}\n")
            |> List.join("")

}
