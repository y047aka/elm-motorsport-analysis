mod Cli.Stages.CsvInput {

    use Util.Files
    use Cli.Errors.CliError

    pub def read(inputPath: String): Result[CliError, String] \ IO =
        forM(
            lines <- Files.readLines(inputPath) |> Result.mapErr(CliError.File);
            _     <- match lines {
                        case Nil => Err(CliError.EmptyFile(inputPath))
                        case _   => Ok(())
                     }
        ) yield List.join("\n", lines)

}
