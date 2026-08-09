mod Cli.Stages.Manifest {

    use Util.Files
    use Util.Json.Encode
    use Util.Json.Encode.JsonValue.{JsonObject, JsonString, JsonInt, JsonArray}
    use Cli.Errors.CliError
    use Motorsport.Calendar
    use Motorsport.Calendar.Round
    use Motorsport.Calendar.Season
    use Motorsport.Events

    /// Where the app serves the season directories from -- the one place the
    /// app's layout is written down, and the reason it is here rather than in
    /// `Motorsport.Calendar`, which is a list of races.
    ///
    /// Not where the files are written to. That is the run's argument, and
    /// `../app/static/wec` and `/static/wec` are the same place reached two
    /// different ways.
    def urlRoot(): String = "/static/wec"

    /// Written beside the season directories rather than inside one, because it
    /// spans all of them.
    pub def write(root: String): Result[CliError, String] \ IO =
        let path = "${root}/index.json";
        Files.write(path, Encode.render(toJson(urlRoot(), Calendar.seasons())))
            |> Result.mapErr(CliError.File)
            |> Result.map(_ -> path)

    /// The file the app reads before it has asked for a round.
    ///
    /// The paths are stated rather than left to a rule the reader reproduces. A
    /// convention both sides know is two copies of it, and the app has no way to
    /// notice when its copy stops matching where the files went.
    pub def toJson(urlRoot: String, seasons: List[Season]): Encode.JsonValue =
        JsonObject(
            ("seasons", JsonArray(seasons |> List.map(seasonToJson(urlRoot)))) ::
            Nil
        )

    def seasonToJson(urlRoot: String): Season -> Encode.JsonValue =
        s -> JsonObject(
            ("season", JsonInt(s#season)) ::
            ("rounds", JsonArray(s#rounds |> List.map(roundToJson(urlRoot, s#season)))) ::
            Nil
        )

    def roundToJson(urlRoot: String, season: Int32): Round -> Encode.JsonValue =
        r -> {
            let stem = "${urlRoot}/${season}/${r#id}";
            JsonObject(
                ("id",      JsonString(r#id)) ::
                ("name",    JsonString(Events.displayName(r#id))) ::
                ("date",    JsonString(r#date)) ::
                ("summary", JsonString("${stem}.json")) ::
                ("laps",    JsonString("${stem}_laps.json")) ::
                Nil
            )
        }

}
