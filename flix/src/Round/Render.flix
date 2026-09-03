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
        let metadataJson = Extra.render(Metadata.toJson(metadata));
        let lapsJsonl    = renderJsonl(rawLaps);
        {
            lapCount     = List.length(rawLaps),
            metadataJson = metadataJson,
            lapsJsonl    = lapsJsonl
        }

    pub def renderJsonl(rawLaps: List[RawLap]): String =
        rawLaps
            |> List.map(rawLap -> "${Extra.renderOnOneLine(Wec.toJson(rawLap))}\n")
            |> List.join("")

}
