mod Cli.Manifest {

    use Util.Files
    use Util.Json.Encode.Extra
    use Cli.Errors.CliError
    use Motorsport.Calendar

    /// Where the app serves the season directories from -- the one place the
    /// app's layout is written down, and the reason it is here rather than in
    /// `Motorsport.Calendar`, which is a list of races.
    ///
    /// Not where the files are written to. That is the run's argument, and
    /// `../app/static/wec` and `/static/wec` are the same place reached two
    /// different ways.
    pub def urlRoot(): String = "/static/wec"

    /// Written beside the season directories rather than inside one, because it
    /// spans all of them.
    pub def write(root: String): Result[CliError, String] \ IO =
        let path = "${root}/index.json";
        Files.write(path, Extra.render(Manifest.toJson(urlRoot(), Calendar.seasons())))
            |> Result.mapErr(CliError.File)
            |> Result.map(_ -> path)

}
