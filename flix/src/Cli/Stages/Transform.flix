mod Cli.Stages.Transform {

    use Util.Json.Encode.Extra
    use Util.Json.Encode.JsonValue.JsonArray
    use Motorsport.Calendar.Entry
    use Motorsport.Metadata
    use Motorsport.Wec
    use Motorsport.Wec.RawLap

    pub type alias Rendered = {
        lapCount     = Int32,
        metadataJson = String,
        lapsJson     = String
    }

    pub def transform(entry: Entry, rawLaps: List[RawLap]): Rendered =
        let metadata     = Metadata.fromRawLaps(entry, rawLaps);
        let metadataJson = Extra.render(Metadata.toJson(metadata));
        let lapsJson     = Extra.render(JsonArray(List.map(Wec.toJson, rawLaps)));
        {
            lapCount     = List.length(rawLaps),
            metadataJson = metadataJson,
            lapsJson     = lapsJson
        }

}
