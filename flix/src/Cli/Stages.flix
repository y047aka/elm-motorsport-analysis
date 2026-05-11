mod Cli.Stages {

    use Sys.Console
    use Cli.Errors.CliError
    use Cli.FileTask
    use Cli.Stages.CsvInput
    use Cli.Stages.Output
    use Cli.Stages.Transform
    use Cli.Stages.Transform.Rendered
    use Cli.Validation
    use RawLap.RawLap

    type alias ProcessingReport = {
        lapCount   = Int32,
        outputPath = String,
        lapsPath   = String
    }

    type alias RunSummary = {
        processed = Int32,
        errors    = Int32
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

    /// Pipeline: read CSV -> report violations -> render JSON -> write JSON
    /// -> turn the Rendered struct into a user-facing ProcessingReport.
    /// Each helper closes over `task` so the chain is composed with `|>`
    /// alone, without threading an explicit pipeline-state record.
    def processFile(task: FileTask.FileTask): Result[CliError, ProcessingReport] \ {IO, Console} =
        CsvInput.readRawLaps(task#inputPath)
            |> Result.map(reportViolations(task))
            |> Result.map(render(task))
            |> Result.flatMap(write(task))
            |> Result.map(toReport(task))

    def reportViolations(task: FileTask.FileTask): List[RawLap] -> List[RawLap] \ Console =
        rawLaps -> {
            Validation.validate(task#eventName, rawLaps) |> List.forEach(Console.eprintln);
            rawLaps
        }

    def render(task: FileTask.FileTask): List[RawLap] -> Rendered =
        rawLaps -> Transform.transform(task#eventName, rawLaps)

    /// Writes the rendered JSON and passes `Rendered` through on success
    /// so downstream stages can still see lapCount.
    def write(task: FileTask.FileTask): Rendered -> Result[CliError, Rendered] \ IO =
        rendered -> Output.writeOutputs(task, rendered) |> Result.map(_ -> rendered)

    def toReport(task: FileTask.FileTask): Rendered -> ProcessingReport =
        rendered -> {
            lapCount   = rendered#lapCount,
            outputPath = task#outputPath,
            lapsPath   = task#lapsPath
        }

}
