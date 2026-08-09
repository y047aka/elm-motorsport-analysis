mod Cli.Stages.Manifest {

    use Util.Files
    use Util.Json.Encode
    use Util.Json.Encode.JsonValue.{JsonObject, JsonString, JsonInt, JsonArray}
    use Cli.Errors.CliError
    use Motorsport.Calendar
    use Motorsport.Calendar.Round
    use Motorsport.Calendar.Season
    use Motorsport.Events

    /// Where the app serves the season directories from.
    ///
    /// This is the one place the app's layout is written down. The paths inside
    /// index.json are built from it, and the app reads them rather than
    /// rebuilding them, so a move is one edit here and not one on each side.
    ///
    /// It is not the directory the files are written to -- that is the run's
    /// argument, and `../app/static/wec` and `/static/wec` are the same place
    /// reached two different ways. Which is also why the layout lives here and
    /// not in `Motorsport.Calendar`: a calendar is a list of races, and where a
    /// web app serves its files from is not something a race knows.
    def urlRoot(): String = "/static/wec"

    /// The file the app reads before it has asked for a round: which seasons
    /// there are, which rounds each of them ran, and where each round's files
    /// are.
    ///
    /// It is written beside the season directories rather than inside one,
    /// because it spans all of them. Its contents come from the calendar alone,
    /// so what a run converted has no bearing on it.
    pub def write(root: String): Result[CliError, String] \ IO =
        let path = "${root}/index.json";
        Files.write(path, Encode.render(toJson(urlRoot(), Calendar.seasons())))
            |> Result.mapErr(CliError.File)
            |> Result.map(_ -> path)

    /// The calendar as the app reads it: the names, and where each round's files
    /// are served from.
    ///
    /// The paths are stated rather than left to a rule the reader reproduces.
    /// A convention both sides know is two copies of it, and the app has no way
    /// to notice when its copy stops matching where the files actually went.
    ///
    /// The names are resolved here too, so the index page and the summary of the
    /// round it links to cannot end up calling the same race two different
    /// things.
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
