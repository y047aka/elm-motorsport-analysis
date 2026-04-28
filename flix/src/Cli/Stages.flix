mod Cli.Stages {

    use Util.Csv
    use Util.Files
    use Util.Json
    use Motorsport.Metadata
    use Cli.Errors.CliError
    use Cli.FileTask
    use Cli.Log

    pub type alias Output = {
        lapCount     = Int32,
        metadataJson = String,
        lapsJson     = String
    }

    type alias ProcessingReport = {
        lapCount   = Int32,
        outputPath = String,
        lapsPath   = String
    }

    type alias RunSummary = {
        processed = Int32,
        errors    = Int32
    }

    pub def process(eventId: String, dataLines: List[String]): Output =
        let rawLaps      = dataLines |> Csv.parse |> RawLap.fromCsvRows;
        let metadata     = Metadata.fromRawLaps(eventId, rawLaps);
        let metadataJson = Json.render(Metadata.toJson(metadata));
        let lapsJson     = Json.render(RawLap.toJsonArray(rawLaps));
        {
            lapCount     = List.length(rawLaps),
            metadataJson = metadataJson,
            lapsJson     = lapsJson
        }

    pub def runAll(tasks: List[FileTask.FileTask]): Int32 \ IO =
        let summary = List.foldLeft(
            (acc, task) -> match processFile(task) {
                case Ok(report) =>
                    Log.info("${task#eventName}: Wrote ${report#lapCount} laps");
                    Log.info("${task#eventName}: Metadata -> ${report#outputPath}");
                    Log.info("${task#eventName}: Laps     -> ${report#lapsPath}");
                    { processed = acc#processed + 1, errors = acc#errors }
                case Err(e) =>
                    Log.error("${task#eventName}: ${e}");
                    { processed = acc#processed, errors = acc#errors + 1 }
            },
            { processed = 0, errors = 0 },
            tasks
        );
        Log.info("Processing completed: ${summary#processed} processed, ${summary#errors} errors");
        if (summary#errors == 0) 0 else 1

    def processFile(task: FileTask.FileTask): Result[CliError, ProcessingReport] \ IO =
        let inputPath  = task#inputPath;
        let outputPath = task#outputPath;
        let lapsPath   = task#lapsPath;
        let eventName  = task#eventName;
        forM(
            lines     <- Files.readLines(inputPath) |> Result.mapErr(CliError.File);
            dataLines <- match lines {
                            case _ :: rest => Ok(rest)
                            case Nil       => Err(CliError.EmptyFile(inputPath))
                         };
            processed <- Ok(process(eventName, dataLines));
            _         <- Files.writeFile(outputPath, processed#metadataJson) |> Result.mapErr(CliError.File);
            _         <- Files.writeFile(lapsPath, processed#lapsJson) |> Result.mapErr(CliError.File)
        ) yield {
            lapCount   = processed#lapCount,
            outputPath = outputPath,
            lapsPath   = lapsPath
        }

}
