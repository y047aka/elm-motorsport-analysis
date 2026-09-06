mod Cli.Load {

    use Db.Cars
    use Db.Laps

    use Sys.Console
    use Util.Files
    use Db.CarRow
    use Db.LapRow
    use Cli.Errors.CliError
    use Cli.FileTask
    use Cli.Load.CsvDecode
    use Cli.Load.CsvInput
    use Cli.Load.Unlisted
    use Cli.Load.Validation
    use Motorsport.Wec.RawLap

    type alias RunSummary = {
        processed = Int32,
        errors    = Int32
    }

    /// What the round put in each table, which is what the database took
    /// rather than what the file decoded to.
    type alias Loaded = {
        cars = Int32,
        laps = Int32
    }

    /// The tables are dropped and rebuilt, so the run is one transaction: a
    /// run that dies partway through leaves the rounds it was rebuilding from.
    /// A round the database refused is reported and counted, and the rounds
    /// beside it are still committed.
    pub def runAll(root: String): Int32 \ {IO, Console, Db} =
        let rebuild = Db.transact(() -> match createTables() {
            case Err(e) => Err(e)
            case Ok(()) => Ok(convertRounds(root))
        });
        match rebuild {
            case Err(e) =>
                Console.eprintln("Database: ${e}");
                1
            case Ok(code) =>
                code
        }

    /// Belongs before the first round: a schema this database will not take
    /// would otherwise be reported once per round, in the same words.
    def createTables(): Result[String, Unit] \ DbWrite =
        forM(
            _ <- Cars.create();
            _ <- Laps.create()
        ) yield ()

    /// The calendar is the worklist, so a run converts the rounds it holds and
    /// nothing else. Two ways that can be wrong, and both are said out loud: a
    /// round with no CSV fails the run, and a CSV no round names is reported and
    /// left alone.
    def convertRounds(root: String): Int32 \ {IO, Console, Db} =
        let tasks = FileTask.fromCalendar(root);
        let summary = List.foldLeft(
            (acc, task) -> match processFile(task) {
                case Ok(loaded) =>
                    Console.println("${FileTask.label(task)}: Rows -> ${loaded#laps} laps, ${loaded#cars} cars loaded");
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

    def processFile(task: FileTask.FileTask): Result[CliError, Loaded] \ {IO, Console, Db} =
        CsvInput.read(task#inputPath)
            |> Result.flatMap(decode(task))
            |> Result.flatMap(reportCarDisagreements(task))
            |> Result.flatMap(load(task))
            |> Result.flatMap(reportViolations(task))

    def decode(task: FileTask.FileTask): String -> Result[CliError, List[RawLap]] =
        content -> CsvDecode.decode(task#inputPath, content)

    /// `Db.CarRow` keeps a car's first description and the second reaches no
    /// column, so a file that describes one car two ways is said here or
    /// nowhere. It is a reading of the file rather than of the rows, which is
    /// why it is a stage of its own before the one that sends them.
    def reportCarDisagreements(task: FileTask.FileTask): List[RawLap] -> Result[CliError, List[RawLap]] \ Console =
        rawLaps -> {
            CarRow.disagreements(rawLaps)
                |> List.forEach(d -> Console.eprintln(
                    "${task#entry#id}: [car ${d#carNumber} #${d#lapNumber}] car-description: "
                        + "${d#field} kept=\"${d#kept}\" found=\"${d#found}\""));
            Ok(rawLaps)
        }

    def load(task: FileTask.FileTask): List[RawLap] -> Result[CliError, Loaded] \ DbWrite =
        rawLaps ->
            let loaded = forM(
                cars <- Cars.insertRows(CarRow.fromRawLaps(task#entry, rawLaps));
                laps <- Laps.insertRows(LapRow.fromRawLaps(task#entry, rawLaps))
            ) yield { cars = cars, laps = laps };
            loaded |> Result.mapErr(CliError.Database)

    def reportViolations(task: FileTask.FileTask): Loaded -> Result[CliError, Loaded] \ {Console, DbRead} =
        loaded ->
            Validation.validate(task#entry)
                |> Result.mapErr(CliError.Database)
                |> Result.map(messages -> {
                    messages |> List.forEach(Console.eprintln);
                    loaded
                })

}
