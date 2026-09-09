mod Round.Render {

    use Util.Json.Encode.Extra
    use Util.Json.Encode.JsonValue
    use Motorsport.Index
    use Motorsport.Metadata
    use Motorsport.Timeline
    use Motorsport.Wec
    use Round.Laps.Placed

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

    pub def renderTimelineJsonl(events: List[Timeline.Event]): String =
        events
            |> List.map(event -> "${Extra.renderOnOneLine(Timeline.toJson(event))}\n")
            |> List.join("")

    pub def renderJsonl(laps: List[Placed]): String =
        laps
            |> List.map(lap -> "${Extra.renderOnOneLine(withPosition(Wec.toJson(lap#lap), lap#position))}\n")
            |> List.join("")

    def withPosition(lap: JsonValue, position: Int32): JsonValue =
        match lap {
            case JsonValue.JsonObject(fields) =>
                JsonValue.JsonObject(List.append(fields, ("position", JsonValue.JsonInt(position)) :: Nil))
            case other => other
        }

}
