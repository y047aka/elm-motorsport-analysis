mod Cli.Stages {

    use Sys.Console
    use Util.Files
    use Cli.Db
    use Cli.Db.LapRow
    use Cli.Errors.CliError
    use Cli.FileTask
    use Cli.Stages.CsvDecode
    use Cli.Stages.CsvInput
    use Cli.Stages.Manifest
    use Cli.Stages.Output
    use Cli.Stages.Summary
    use Cli.Stages.Transform
    use Cli.Stages.Transform.Rendered
    use Cli.Stages.Unlisted
    use Cli.Stages.Validation
    use Motorsport.Metadata
    use Motorsport.Wec.RawLap

    type alias ProcessingReport = {
        lapCount   = Int32,
        outputPath = String,
        lapsPath   = String,
        loadedRows = Int32
    }

    type alias RunSummary = {
        processed = Int32,
        errors    = Int32
    }

    pub def runAll(root: String): Int32 \ {IO, Console, Db} =
        match Db.prepare() {
            case Err(e) =>
                Console.eprintln("Database: ${e}");
                1
            case Ok(()) =>
                convertRounds(root)
        }

    /// The calendar is the worklist, so a run converts the rounds it holds and
    /// nothing else. Two ways that can be wrong, and both are said out loud: a
    /// round with no CSV fails the run, and a CSV no round names is reported and
    /// left alone.
    def convertRounds(root: String): Int32 \ {IO, Console, Db} =
        let tasks = FileTask.fromCalendar(root);
        let summary = List.foldLeft(
            (acc, task) -> match processFile(task) {
                case Ok(report) =>
                    Console.println("${FileTask.label(task)}: Wrote ${report#lapCount} laps");
                    Console.println("${FileTask.label(task)}: Metadata -> ${report#outputPath}");
                    Console.println("${FileTask.label(task)}: Laps     -> ${report#lapsPath}");
                    reportLoad(task, report);
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

    def reportLoad(task: FileTask.FileTask, report: ProcessingReport): Unit \ Console =
        if (report#loadedRows > 0)
            Console.println("${FileTask.label(task)}: Rows     -> ${report#loadedRows} loaded")
        else
            ()

    /// Not an error: the run converted everything it was asked for, and this is
    /// about what it was not asked for. Saying it is what keeps a forgotten line
    /// in `Motorsport.Calendar` from passing for a clean run.
    def reportUnlistedCsvFiles(root: String, tasks: List[FileTask.FileTask]): Unit \ {IO, Console} =
        match Files.walkCsvFiles(root) {
            case Err(e) => Console.eprintln("Calendar: could not check for unlisted CSV files (${e})")
            case Ok(found) =>
                Unlisted.detect(tasks, found)
                    |> List.forEach(path ->
                        Console.eprintln("Calendar: ${path} is not on the calendar, skipped")
                    )
        }

    /// Written once for the run, not once per file, and written even by a run
    /// that decoded nothing: the calendar is not made from the laps.
    def writeCalendar(root: String): Int32 \ {IO, Console} =
        match Manifest.write(root) {
            case Ok(path) =>
                Console.println("Calendar -> ${path}");
                0
            case Err(e) =>
                Console.eprintln("Calendar: ${e}");
                1
        }

    def processFile(task: FileTask.FileTask): Result[CliError, ProcessingReport] \ {IO, Console, Db} =
        CsvInput.read(task#inputPath)
            |> Result.flatMap(decode(task))
            |> Result.flatMap(load(task))
            |> Result.flatMap(reportViolations(task))
            |> Result.flatMap(summarise(task))
            |> Result.flatMap(write(task))

    def decode(task: FileTask.FileTask): String -> Result[CliError, List[RawLap]] =
        content -> CsvDecode.decode(task#inputPath, content)

    /// The rows go in before anything reads the round back, because the checks
    /// are made of what the database holds and not of the laps in hand.
    def load(task: FileTask.FileTask): List[RawLap] -> Result[CliError, (List[RawLap], Int32)] \ Db =
        rawLaps ->
            Db.insertLaps(LapRow.fromRawLaps(task#entry, rawLaps))
                |> Result.mapErr(CliError.Database)
                |> Result.map(loadedRows -> (rawLaps, loadedRows))

    def reportViolations(task: FileTask.FileTask): ((List[RawLap], Int32)) -> Result[CliError, (List[RawLap], Int32)] \ {Console, Db} =
        match (rawLaps, loadedRows) ->
            Validation.validate(task#entry)
                |> Result.mapErr(CliError.Database)
                |> Result.map(messages -> {
                    messages |> List.forEach(Console.eprintln);
                    (rawLaps, loadedRows)
                })

    def summarise(task: FileTask.FileTask): ((List[RawLap], Int32)) -> Result[CliError, (List[RawLap], Int32, Metadata.Metadata)] \ Db =
        match (rawLaps, loadedRows) ->
            Summary.read(task#entry)
                |> Result.mapErr(CliError.Database)
                |> Result.map(metadata -> (rawLaps, loadedRows, metadata))

    def write(task: FileTask.FileTask): ((List[RawLap], Int32, Metadata.Metadata)) -> Result[CliError, ProcessingReport] \ IO =
        match (rawLaps, loadedRows, metadata) -> {
            let rendered = Transform.transform(metadata, rawLaps);
            Output.write(task, rendered) |> Result.map(_ -> toReport(task, rendered, loadedRows))
        }

    def toReport(task: FileTask.FileTask, rendered: Rendered, loadedRows: Int32): ProcessingReport =
        {
            lapCount   = rendered#lapCount,
            outputPath = task#outputPath,
            lapsPath   = task#lapsPath,
            loadedRows = loadedRows
        }

}
