mod Stages {

    pub type alias Output = {
        lapCount     = Int32,
        metadataJson = String,
        lapsJson     = String
    }

    pub def process(eventId: String, dataLines: List[String]): Output =
        let rawLaps      = dataLines |> Csv.parse |> RawLap.fromCsvRows;
        let metadata     = Metadata.fromRawLaps(eventId, rawLaps);
        let metadataJson = Json.render(Metadata.toJson(metadata));
        let lapsJson     = Json.render(RawLap.toJsonArray(rawLaps));
        {
            lapCount     = List.length(rawLaps),
            metadataJson = metadataJson,
            lapsJson     = lapsJson
        }

}
