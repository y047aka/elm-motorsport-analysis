mod Cli.Stages.CsvInput {

    use Util.Csv.Decode
    use Util.Csv.Decode.FieldNames
    use Util.Files
    use Cli.Errors.CliError
    use Cli.Stages.State
    use RawLap.RawLap

    /// Pipeline stage: read the CSV referenced by the State's task and
    /// populate `rawLaps`.
    pub def step(s: State.State): Result[CliError, State.State] \ IO =
        readRawLaps(s#task#inputPath) |> Result.map(rl -> { rawLaps = rl | s })

    /// Reads a CSV file from disk and decodes it into a list of `RawLap`.
    ///
    /// Some CSV files are saved with a UTF-8 BOM (﻿) by Windows
    /// tools. Strip it here at the I/O boundary before decoding so the
    /// CSV library stays agnostic about file encoding details.
    /// FieldNamesFromFirstRow consumes the first line as column names,
    /// making them available for field-based decoding in RawLap.decoder.
    pub def readRawLaps(inputPath: String): Result[CliError, List[RawLap]] \ IO =
        forM(
            lines   <- Files.readLines(inputPath) |> Result.mapErr(CliError.File);
            _       <- match lines {
                          case Nil => Err(CliError.EmptyFile(inputPath))
                          case _   => Ok(())
                       };
            content <- Ok({
                          let raw = List.join("\n", lines);
                          if (String.startsWith({prefix = "﻿"}, raw)) String.dropLeft(1, raw) else raw
                       });
            rawLaps <- Decode.decodeCustom(
                          {fieldSeparator = ';'},
                          FieldNames.FieldNamesFromFirstRow,
                          RawLap.decoder(),
                          content
                       ) |> Result.mapErr(e -> CliError.Csv({ path = inputPath, message = Decode.errorToString(e) }))
        ) yield rawLaps

}
