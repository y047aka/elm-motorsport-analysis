mod Round.Render {

    use Util.Json.Encode.Extra
    use Motorsport.Metadata
    use Motorsport.Wec
    use Motorsport.Wec.RawLap

    pub type alias Rendered = {
        lapCount     = Int32,
        metadataJson = String,
        lapsJsonl    = String
    }

    pub def render(metadata: Metadata.Metadata, rawLaps: List[RawLap]): Rendered =
        {
            lapCount     = List.length(rawLaps),
            metadataJson = renderMetadata(metadata),
            lapsJsonl    = renderJsonl(rawLaps)
        }

    /// Reached on its own by an answer that carries the summary without the
    /// laps, which is a round's worth of rows it would otherwise read to throw
    /// away.
    pub def renderMetadata(metadata: Metadata.Metadata): String =
        Extra.render(Metadata.toJson(metadata))

    pub def renderJsonl(rawLaps: List[RawLap]): String =
        rawLaps
            |> List.map(rawLap -> "${Extra.renderOnOneLine(Wec.toJson(rawLap))}\n")
            |> List.join("")

}
