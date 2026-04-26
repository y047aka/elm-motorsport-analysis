mod Pipeline {

    pub type alias Result = {
        lapCount = Int32,
        json = String
    }

    pub def process(dataLines: List[String]): Result =
        let records = Csv.parseLines(dataLines);
        let json = Json.render(Lap.toJsonArray(records));
        {
            lapCount = List.length(records),
            json     = json
        }

}
