mod Cli.Stages.Transform {

    use Util.Json.Encode
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
        let metadataJson = Encode.render(Metadata.toJson(metadata));
        let lapsJson     = Encode.render(JsonArray(List.map(Wec.toJson, rawLaps)));
        {
            lapCount     = List.length(rawLaps),
            metadataJson = metadataJson,
            lapsJson     = lapsJson
        }

}
