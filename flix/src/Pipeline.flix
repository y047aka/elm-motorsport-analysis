mod Pipeline {

    pub def process(dataLines: List[String]): String =
        dataLines
            |> Csv.parseLines
            |> Lap.toJsonArray
            |> Json.render

}
