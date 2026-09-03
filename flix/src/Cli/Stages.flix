mod Cli.Stages {

    use Sys.Console
    use Util.Files
    use Db.LapRow
    use Cli.Errors.CliError
    use Cli.FileTask
    use Cli.Stages.CsvDecode
    use Cli.Stages.CsvInput
    use Cli.Stages.Unlisted
    use Cli.Stages.Validation
    use Motorsport.Wec.RawLap

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
                case Ok(loadedRows) =>
                    Console.println("${FileTask.label(task)}: Rows -> ${loadedRows} loaded");
                    { processed = acc#processed + 1 | acc }
                case Err(e) =>
                    Console.eprintln("${FileTask.label(task)}: ${e}");
                    { errors = acc#errors + 1 | acc }
            },
            { processed = 0, errors = 0 },
            tasks
        );
        reportUnlistedCsvFiles(root, tasks);
        Console.println("Processing completed: ${summary#processed} processed, ${summary#errors} errors");
        if (summary#errors == 0) 0 else 1

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

    def processFile(task: FileTask.FileTask): Result[CliError, Int32] \ {IO, Console, Db} =
        CsvInput.read(task#inputPath)
            |> Result.flatMap(decode(task))
            |> Result.flatMap(load(task))
            |> Result.flatMap(reportViolations(task))

    def decode(task: FileTask.FileTask): String -> Result[CliError, List[RawLap]] =
        content -> CsvDecode.decode(task#inputPath, content)

    def load(task: FileTask.FileTask): List[RawLap] -> Result[CliError, Int32] \ Db =
        rawLaps ->
            Db.insertLaps(LapRow.fromRawLaps(task#entry, rawLaps))
                |> Result.mapErr(CliError.Database)

    def reportViolations(task: FileTask.FileTask): Int32 -> Result[CliError, Int32] \ {Console, Db} =
        loadedRows ->
            Validation.validate(task#entry)
                |> Result.mapErr(CliError.Database)
                |> Result.map(messages -> {
                    messages |> List.forEach(Console.eprintln);
                    loadedRows
                })

}
