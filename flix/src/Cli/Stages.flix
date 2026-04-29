mod Cli.Stages {

    use Util.Csv
    use Util.Files
    use Util.Json
    use Motorsport.Metadata
    use Sys.Console
    use Cli.Errors.CliError
    use Cli.FileTask
    use Cli.Validation
    use RawLap.RawLap

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

    pub def process(eventId: String, rawLaps: List[RawLap]): Output =
        let metadata     = Metadata.fromRawLaps(eventId, rawLaps);
        let metadataJson = Json.render(Metadata.toJson(metadata));
        let lapsJson     = Json.render(RawLap.toJsonArray(rawLaps));
        {
            lapCount     = List.length(rawLaps),
            metadataJson = metadataJson,
            lapsJson     = lapsJson
        }

    pub def runAll(tasks: List[FileTask.FileTask]): Int32 \ {IO, Console} =
        let summary = List.foldLeft(
            (acc, task) -> match processFile(task) {
                case Ok(report) =>
                    Console.println("${task#eventName}: Wrote ${report#lapCount} laps");
                    Console.println("${task#eventName}: Metadata -> ${report#outputPath}");
                    Console.println("${task#eventName}: Laps     -> ${report#lapsPath}");
                    { processed = acc#processed + 1, errors = acc#errors }
                case Err(e) =>
                    Console.eprintln("${task#eventName}: ${e}");
                    { processed = acc#processed, errors = acc#errors + 1 }
            },
            { processed = 0, errors = 0 },
            tasks
        );
        Console.println("Processing completed: ${summary#processed} processed, ${summary#errors} errors");
        if (summary#errors == 0) 0 else 1

    def processFile(task: FileTask.FileTask): Result[CliError, ProcessingReport] \ {IO, Console} =
        match Files.readLines(task#inputPath) |> Result.mapErr(CliError.File) {
            case Err(e)             => Err(e)
            case Ok(Nil)            => Err(CliError.EmptyFile(task#inputPath))
            case Ok(_ :: dataLines) =>
                let rawLaps = dataLines |> Csv.parse |> RawLap.fromCsvRows;
                reportViolations(Validation.validate(task#eventName, rawLaps));
                let processed = process(task#eventName, rawLaps);
                forM(
                    _ <- Files.writeFile(task#outputPath, processed#metadataJson) |> Result.mapErr(CliError.File);
                    _ <- Files.writeFile(task#lapsPath, processed#lapsJson) |> Result.mapErr(CliError.File)
                ) yield {
                    lapCount   = processed#lapCount,
                    outputPath = task#outputPath,
                    lapsPath   = task#lapsPath
                }
        }

    def reportViolations(violations: List[String]): Unit \ Console =
        violations |> List.forEach(Console.eprintln)

}
