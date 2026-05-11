mod Cli.Stages.CsvInput {

    use Util.Csv.Decode
    use Util.Csv.Decode.FieldNames
    use Util.Files
    use Cli.Errors.CliError
    use RawLap.RawLap

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

    /// Decodes CSV content into a list of `RawLap`. Strips a leading UTF-8
    /// BOM (﻿) some Windows tools emit before handing the text to the
    /// decoder. `inputPath` is only used to attach context to `CliError.Csv`.
    /// FieldNamesFromFirstRow consumes the first line as column names,
    /// making them available for field-based decoding in RawLap.decoder.
    pub def decodeRawLaps(inputPath: String, content: String): Result[CliError, List[RawLap]] =
        let stripped =
            if (String.startsWith({prefix = "﻿"}, content)) String.dropLeft(1, content) else content;
        Decode.decodeCustom(
            {fieldSeparator = ';'},
            FieldNames.FieldNamesFromFirstRow,
            RawLap.decoder(),
            stripped
        ) |> Result.mapErr(e -> CliError.Csv({ path = inputPath, message = Decode.errorToString(e) }))

    /// Orchestrates `readSource` and `decodeRawLaps` for the common case.
    pub def readRawLaps(inputPath: String): Result[CliError, List[RawLap]] \ IO =
        forM(
            content <- readSource(inputPath);
            rawLaps <- decodeRawLaps(inputPath, content)
        ) yield rawLaps

}
