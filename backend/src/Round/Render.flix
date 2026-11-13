pub mod Round.Render {

    use oj::OrderedJson.Json
    use oj::OrderedJson.Json.{JObject, JNumber}
    use Util.Json.Extra
    use Motorsport.Index
    use Motorsport.Metadata
    use Motorsport.Timeline
    use Motorsport.Wec
    use Round.Laps.Placed

    /// The round's summary and the indices read off the same rows, written as
    /// one document.
    pub def renderSummary(metadata: Metadata.Metadata, index: Index.Index): String =
        Extra.render(withIndex(Metadata.toJson(metadata), Index.toJson(index)))

    def withIndex(metadata: Json, index: Json): Json =
        match metadata {
            case JObject(fields) =>
                JObject(List.append(fields, ("index", index) :: Nil))
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

    def withPosition(lap: Json, position: Int32): Json =
        match lap {
            case JObject(fields) =>
                JObject(List.append(fields, ("position", JNumber(Int32.toBigDecimal(position))) :: Nil))
            case other => other
        }

}
