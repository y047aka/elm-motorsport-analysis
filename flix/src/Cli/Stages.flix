mod Cli.Stages {

    use Sys.Console
    use Util.Files
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

    /// The calendar is the worklist, so a run converts the rounds it holds and
    /// nothing else. Two ways that can be wrong, and both are said out loud: a
    /// round with no CSV fails the run, and a CSV no round names is reported and
    /// left alone.
    pub def runAll(root: String): Int32 \ {IO, Console} =
        let tasks = FileTask.fromCalendar(root);
        let summary = List.foldLeft(
            (acc, task) -> match processFile(task) {
                case Ok(report) =>
                    Console.println("${FileTask.label(task)}: Wrote ${report#lapCount} laps");
                    Console.println("${FileTask.label(task)}: Metadata -> ${report#outputPath}");
                    Console.println("${FileTask.label(task)}: Laps     -> ${report#lapsPath}");
                    { processed = acc#processed + 1 | acc }
                case Err(e) =>
                    Console.eprintln("${FileTask.label(task)}: ${e}");
                    { errors = acc#errors + 1 | acc }
            },
            { processed = 0, errors = 0 },
            tasks
        );
        reportUnlistedCsvFiles(root, tasks);
        let calendarErrors = writeCalendar(root);
        let errors = summary#errors + calendarErrors;
        Console.println("Processing completed: ${summary#processed} processed, ${errors} errors");
        if (errors == 0) 0 else 1

    /// A CSV nothing on the calendar names is skipped, and saying so is the only
    /// way adding a round can fail loudly rather than quietly: the file is
    /// there, the round is not, and the fix is one line in
    /// `Motorsport.Calendar`.
    ///
    /// Not an error. The run converted everything it was asked for; this is
    /// about what it was not asked for.
    def reportUnlistedCsvFiles(root: String, tasks: List[FileTask.FileTask]): Unit \ {IO, Console} =
        match Files.walkCsvFiles(root) {
            case Err(e) => Console.eprintln("Calendar: could not check for unlisted CSV files (${e})")
            case Ok(found) =>
                let listed = tasks |> List.map(task -> task#inputPath);
                found
                    |> List.filter(path -> not List.memberOf(path, listed))
                    |> List.forEach(path ->
                        Console.eprintln("Calendar: ${path} is not on the calendar, skipped")
                    )
        }

    /// The calendar is not made from the laps, so it is written once for the run
    /// rather than once per file, and a run that decoded nothing still writes it.
    def writeCalendar(root: String): Int32 \ {IO, Console} =
        match Manifest.write(root) {
            case Ok(path) =>
                Console.println("Calendar -> ${path}");
                0
            case Err(e) =>
                Console.eprintln("Calendar: ${e}");
                1
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
            Validation.validate(task#entry#id, rawLaps) |> List.forEach(Console.eprintln);
            rawLaps
        }

    def render(task: FileTask.FileTask): List[RawLap] -> Rendered =
        rawLaps -> Transform.transform(task#entry, rawLaps)

    def write(task: FileTask.FileTask): Rendered -> Result[CliError, Rendered] \ IO =
        rendered -> Output.write(task, rendered) |> Result.map(_ -> rendered)

    def toReport(task: FileTask.FileTask): Rendered -> ProcessingReport =
        rendered -> {
            lapCount   = rendered#lapCount,
            outputPath = task#outputPath,
            lapsPath   = task#lapsPath
        }

}
