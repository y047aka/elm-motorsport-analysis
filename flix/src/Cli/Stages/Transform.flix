mod Cli.Stages.Transform {

    use Util.Json.Encode.Extra
    use Motorsport.Calendar.Entry
    use Motorsport.Metadata
    use Motorsport.Wec
    use Motorsport.Wec.RawLap

    pub type alias Rendered = {
        lapCount     = Int32,
        metadataJson = String,
        lapsJsonl    = String
    }

    pub def transform(entry: Entry, rawLaps: List[RawLap]): Rendered =
        let metadata     = Metadata.fromRawLaps(entry, rawLaps);
        let metadataJson = Extra.render(Metadata.toJson(metadata));
        let lapsJsonl    = renderJsonl(rawLaps);
        {
            lapCount     = List.length(rawLaps),
            metadataJson = metadataJson,
            lapsJsonl    = lapsJsonl
        }

    def renderJsonl(rawLaps: List[RawLap]): String =
        rawLaps
            |> List.map(rawLap -> "${Extra.renderOnOneLine(Wec.toJson(rawLap))}\n")
            |> List.join("")

}
