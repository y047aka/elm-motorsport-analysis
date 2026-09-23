mod Cli.Load.CsvInput {

    use Util.Files
    use Cli.Errors.CliError

    /// Missing is separated from unreadable because, the calendar driving the
    /// run, it means a round was listed and its CSV was never filed.
    pub def read(inputPath: String): Result[CliError, String] \ IO =
        forM(
            exists <- Files.exists(inputPath) |> Result.mapErr(CliError.File);
            _      <- if (exists) Ok(()) else Err(CliError.InputPathNotFound(inputPath));
            lines <- Files.readLines(inputPath) |> Result.mapErr(CliError.File);
            _     <- match lines {
                        case Nil => Err(CliError.EmptyFile(inputPath))
                        case _   => Ok(())
                     }
        ) yield List.join("\n", lines)

}
