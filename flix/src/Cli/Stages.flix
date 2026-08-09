mod Cli.Stages {

    use Sys.Console
    use Cli.Errors.CliError
    use Cli.FileTask
    use Cli.Stages.CsvDecode
    use Cli.Stages.CsvInput
    use Cli.Stages.Manifest
    use Cli.Stages.Output
    use Cli.Stages.Transform
    use Cli.Stages.Transform.Rendered
    use Cli.Stages.Validation
    use Motorsport.Wec.RawLap

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
                    { processed = acc#processed + 1 | acc }
                case Err(e) =>
                    Console.eprintln("${task#eventName}: ${e}");
                    { errors = acc#errors + 1 | acc }
            },
            { processed = 0, errors = 0 },
            tasks
        );
        let calendarErrors = writeCalendar(tasks);
        Console.println("Processing completed: ${summary#processed} processed, ${summary#errors + calendarErrors} errors");
        if (summary#errors + calendarErrors == 0) 0 else 1

    /// The calendar is not made from the laps, so it is written once for the run
    /// rather than once per file, and a run that decoded nothing still writes it.
    /// Where it goes is the only thing the run decides -- see
    /// `Cli.FileTask.calendarRoot` -- so a run with nowhere to put it says so and
    /// leaves the app's copy alone.
    def writeCalendar(tasks: List[FileTask.FileTask]): Int32 \ {IO, Console} =
        match tasks |> List.filterMap(task -> task#calendarRoot) |> List.head {
            case None =>
                Console.eprintln("Calendar: no season directory in the input path, skipped");
                0
            case Some(root) => match Manifest.write(root) {
                case Ok(path) =>
                    Console.println("Calendar -> ${path}");
                    0
                case Err(e) =>
                    Console.eprintln("Calendar: ${e}");
                    1
            }
        }

    def processFile(task: FileTask.FileTask): Result[CliError, ProcessingReport] \ {IO, Console} =
        CsvInput.read(task#inputPath)
            |> Result.flatMap(decode(task))
            |> Result.map(reportViolations(task))
            |> Result.map(render(task))
            |> Result.flatMap(write(task))
            |> Result.map(toReport(task))

    def decode(task: FileTask.FileTask): String -> Result[CliError, List[RawLap]] =
        content -> CsvDecode.decode(task#inputPath, content)

    def reportViolations(task: FileTask.FileTask): List[RawLap] -> List[RawLap] \ Console =
        rawLaps -> {
            Validation.validate(task#eventName, rawLaps) |> List.forEach(Console.eprintln);
            rawLaps
        }

    def render(task: FileTask.FileTask): List[RawLap] -> Rendered =
        rawLaps -> Transform.transform(task#eventName, task#season, rawLaps)

    def write(task: FileTask.FileTask): Rendered -> Result[CliError, Rendered] \ IO =
        rendered -> Output.write(task, rendered) |> Result.map(_ -> rendered)

    def toReport(task: FileTask.FileTask): Rendered -> ProcessingReport =
        rendered -> {
            lapCount   = rendered#lapCount,
            outputPath = task#outputPath,
            lapsPath   = task#lapsPath
        }

}
