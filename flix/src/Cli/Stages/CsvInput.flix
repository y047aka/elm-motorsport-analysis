mod Cli.Stages.CsvInput {

    use Util.Files
    use Cli.Errors.CliError

    /// Reads a CSV file into a single string. Empty files surface as
    /// `CliError.EmptyFile` so downstream decoding can assume non-empty input.
    pub def readSource(inputPath: String): Result[CliError, String] \ IO =
        forM(
            lines <- Files.readLines(inputPath) |> Result.mapErr(CliError.File);
            _     <- match lines {
                        case Nil => Err(CliError.EmptyFile(inputPath))
                        case _   => Ok(())
                     }
        ) yield List.join("\n", lines)

}
