mod Cli.Stages.Transform {

    use Util.Json
    use Util.Json.JsonValue.JsonArray
    use Motorsport.Metadata
    use Cli.Stages.State
    use Cli.Stages.State.Rendered
    use RawLap.RawLap

    /// Pipeline stage: render the metadata + laps JSON from the rawLaps
    /// already populated on the State.
    pub def run(s: State.State): State.State =
        { rendered = transform(s#task#eventName, s#rawLaps) | s }

    /// Renders the metadata + laps JSON payloads from a list of RawLap.
    /// Kept as a public entry point so unit tests can exercise the pure
    /// transformation without constructing a full pipeline State.
    pub def transform(eventId: String, rawLaps: List[RawLap]): Rendered =
        let metadata     = Metadata.fromRawLaps(eventId, rawLaps);
        let metadataJson = Json.render(Metadata.toJson(metadata));
        let lapsJson     = Json.render(JsonArray(List.map(RawLap.toJson, rawLaps)));
        {
            lapCount     = List.length(rawLaps),
            metadataJson = metadataJson,
            lapsJson     = lapsJson
        }

}
