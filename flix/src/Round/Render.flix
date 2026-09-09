mod Round.Render {

    use Util.Json.Encode.Extra
    use Util.Json.Encode.JsonValue
    use Motorsport.Index
    use Motorsport.Metadata
    use Motorsport.Timeline
    use Motorsport.Wec
    use Round.Laps.Placed

    /// The round's summary, the indices and the timeline read off the same
    /// rows, written as one document.
    pub def renderSummary(
        metadata: Metadata.Metadata,
        index: Index.Index,
        timeline: List[Timeline.Event]
    ): String =
        Extra.render(Metadata.toJson(metadata)
            |> extendedWith("index", Index.toJson(index))
            |> extendedWith("timelineEvents", Timeline.toJson(timeline)))

    def extendedWith(key: String, value: JsonValue, metadata: JsonValue): JsonValue =
        match metadata {
            case JsonValue.JsonObject(fields) =>
                JsonValue.JsonObject(List.append(fields, (key, value) :: Nil))
            case other => other
        }

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
