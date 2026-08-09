mod Cli.Stages.Manifest {

    use Util.Files
    use Util.Json.Encode
    use Cli.Errors.CliError
    use Motorsport.Calendar

    /// Where the app serves the season directories from.
    ///
    /// This is the one place the app's layout is written down. The paths inside
    /// index.json are built from it, and the app reads them rather than
    /// rebuilding them, so a move is one edit here and not one on each side.
    ///
    /// It is not the directory the files are written to -- that is the run's
    /// argument, and `../app/static/wec` and `/static/wec` are the same place
    /// reached two different ways.
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
        Files.write(path, Encode.render(Calendar.toJson(urlRoot())))
            |> Result.mapErr(CliError.File)
            |> Result.map(_ -> path)

}
