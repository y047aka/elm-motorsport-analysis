mod Cli.Stages.CsvDecode {

    use Util.Csv.Decode
    use Util.Csv.Decode.FieldNames
    use Cli.Errors.CliError
    use Motorsport.Wec
    use Motorsport.Wec.RawLap

    /// Strips a leading UTF-8 BOM (U+FEFF) emitted by some Windows tools
    /// before handing the text to the decoder.
    pub def decode(inputPath: String, content: String): Result[CliError, List[RawLap]] =
        let stripped =
            if (String.startsWith({prefix = "\uFEFF"}, content)) String.dropLeft(1, content) else content;
        Decode.decodeCustom(
            {fieldSeparator = ';'},
            FieldNames.FieldNamesFromFirstRow,
            Wec.decoder(),
            stripped
        ) |> Result.mapErr(e -> CliError.Csv({ path = inputPath, message = Decode.errorToString(e) }))

}
