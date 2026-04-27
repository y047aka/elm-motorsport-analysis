mod Pipeline {

    pub type alias Output = {
        lapCount = Int32,
        json = String
    }

    pub def process(dataLines: List[String]): Output =
        let rawLaps = dataLines |> Csv.parse |> RawLap.fromCsvRows;
        let json = Json.render(RawLap.toJsonArray(rawLaps));
        {
            lapCount = List.length(rawLaps),
            json     = json
        }

}
