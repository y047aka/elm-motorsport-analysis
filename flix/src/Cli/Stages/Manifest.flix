mod Cli.Stages.Manifest {

    use Util.Files
    use Util.Json.Encode
    use Cli.Errors.CliError
    use Motorsport.Calendar

    /// The file the app reads before it has asked for a round: which seasons
    /// there are, and which rounds each of them ran.
    ///
    /// It is written beside the season directories rather than inside one,
    /// because it spans all of them -- and its contents do not depend on the run
    /// that produced it. A run over 2026 alone still writes the whole calendar,
    /// which is what keeps a partial run from narrowing the index page.
    pub def write(root: String): Result[CliError, String] \ IO =
        let path = "${root}/index.json";
        Files.write(path, Encode.render(Calendar.toJson()))
            |> Result.mapErr(CliError.File)
            |> Result.map(_ -> path)

}
