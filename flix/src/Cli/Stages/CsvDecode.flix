mod Cli.Stages.CsvDecode {

    use Util.Csv.Decode
    use Util.Csv.Decode.FieldNames
    use Cli.Errors.CliError
    use RawLap.RawLap

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

}
