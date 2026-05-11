mod Cli.Stages.Transform {

    use Util.Json
    use Util.Json.JsonValue.JsonArray
    use Motorsport.Metadata
    use Motorsport.RawLap

    pub type alias Rendered = {
        lapCount     = Int32,
        metadataJson = String,
        lapsJson     = String
    }

    /// Renders the metadata + laps JSON payloads from a list of RawLap.
    pub def transform(eventId: String, rawLaps: List[RawLap.RawLap]): Rendered =
        let metadata     = Metadata.fromRawLaps(eventId, rawLaps);
        let metadataJson = Json.render(Metadata.toJson(metadata));
        let lapsJson     = Json.render(JsonArray(List.map(RawLap.toJson, rawLaps)));
        {
            lapCount     = List.length(rawLaps),
            metadataJson = metadataJson,
            lapsJson     = lapsJson
        }

}
