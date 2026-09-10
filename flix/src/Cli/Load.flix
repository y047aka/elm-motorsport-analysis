mod Cli.Load {

    use Db.CarDrivers
    use Db.Cars
    use Db.Drivers
    use Db.Entries
    use Db.Laps
    use Db.Rounds
    use Db.Rounds.RoundRow
    use Db.TimelineEvents

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
        errors    = Int32,
        numbered  = Numbered
    }

    /// What a run has numbered so far. A run walks the rounds one at a time
    /// and both a driver and an entry turn up in several, so what numbers them
    /// is carried between rounds rather than read back between them.
    type alias Numbered = {
        drivers = Drivers.Numbering,
        entries = Entries.Numbering
    }

    /// What the round put in each table, which is what the database took
    /// rather than what the file decoded to.
    type alias Loaded = {
        entries = Int32,
        cars = Int32,
        seats = Int32,
        laps = Int32,
        events = Int32
    }

    /// The tables are dropped and rebuilt, so the run is one transaction: a
    /// run that dies partway through leaves the rounds it was rebuilding from.
    /// A round the database refused is reported and counted, and the rounds
    /// beside it are still committed.
    pub def runAll(root: String): Int32 \ {IO, Console, SqlRead, SqlWrite} =
        let rebuild = Db.runWithError(() -> Db.transact(() -> {
            let rounds = createTables();
            convertRounds(root, rounds)
        }));
        match rebuild {
            case Err(e) =>
                Console.eprintln("Database: ${e}");
                1
            case Ok(code) =>
                code
        }

    /// Belongs before the first round: a schema this database will not take
    /// would otherwise be reported once per round, in the same words.
    ///
    /// `rounds` is written here rather than per round, since what the other
    /// two carry of a round is an id out of it. The rows come back because
    /// that id is read off them: the reader looks it up in the table, and the
    /// load has nothing to look it up with until the table is written.
    def createTables(): List[RoundRow] \ DbWrite =
        let rounds = Rounds.create(Motorsport.Calendar.entries());
        Drivers.create();
        CarDrivers.create();
        Entries.create();
        Cars.create();
        Laps.create();
        TimelineEvents.create();
        rounds

    /// The calendar is the worklist, so a run converts the rounds it holds and
    /// nothing else. Two ways that can be wrong, and both are said out loud: a
    /// round with no CSV fails the run, and a CSV no round names is reported and
    /// left alone.
    def convertRounds(root: String, rounds: List[RoundRow]): Int32 \ {IO, Console, SqlRead, SqlWrite} =
        let tasks = FileTask.fromCalendar(root);
        let summary = List.foldLeft(
            (acc, task) -> match processFile(rounds, acc#numbered, task) {
                case (Ok(loaded), numbered) =>
                    Console.println("${FileTask.label(task)}: Rows -> ${loaded#laps} laps,"
                        + " ${loaded#cars} cars, ${loaded#seats} seats,"
                        + " ${loaded#events} timeline events,"
                        + " ${loaded#entries} entries loaded");
                    { processed = acc#processed + 1, numbered = numbered | acc }
                case (Err(e), numbered) =>
                    Console.eprintln("${FileTask.label(task)}: ${e}");
                    { errors = acc#errors + 1, numbered = numbered | acc }
            },
            { processed = 0, errors = 0,
              numbered = { drivers = Drivers.noneNumbered(), entries = Entries.noneNumbered() } },
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

    /// The round's rows land together or not at all, and the numbering
    /// follows them: a round that failed leaves no rows, so the names it took
    /// numbers for are free again and the next round numbers them itself.
    ///
    /// Advancing the numbering past a round that failed would leave a name
    /// numbered and unwritten, and every later round would then commit an id
    /// with no row behind it.
    def processFile(
        rounds: List[RoundRow],
        numbering: Numbered,
        task: FileTask.FileTask
    ): (Result[CliError, Loaded], Numbered) \ {IO, Console, SqlRead, SqlWrite} =
        match CsvInput.read(task#inputPath) |> Result.flatMap(decode(task)) {
            case Err(e) => (Err(e), numbering)
            case Ok(rawLaps) =>
                reportDisagreements(task, rawLaps);
                let seats = CarDrivers.seats(rawLaps);
                let (drivers, newDrivers) =
                    Drivers.add(numbering#drivers, seats |> List.map(s -> s#name));
                let (entries, newEntries, differing) = Entries.add(
                    numbering#entries, task#entry#season, CarRow.firstMentions(rawLaps));
                reportEntryDisagreements(task, differing);
                let numbered = { drivers = drivers, entries = entries };
                let outcome = Db.runWithError(() -> Db.atomically("round", () -> reportViolations(
                        task, load(rounds, numbered, newDrivers, newEntries, seats, task, rawLaps))))
                    |> Result.mapErr(CliError.Database);
                (outcome, if (Result.isOk(outcome)) numbered else numbering)
        }

    def decode(task: FileTask.FileTask): String -> Result[CliError, List[RawLap]] =
        content -> CsvDecode.decode(task#inputPath, content)

    /// `Db.CarRow` and `Db.CarDrivers` each keep a first mention and the
    /// second reaches no column, so a file that describes one car -- or names
    /// one seat -- two ways is said here or nowhere. It is a reading of the
    /// file rather than of the rows, which is why it comes before the stage
    /// that sends them.
    def reportDisagreements(task: FileTask.FileTask, rawLaps: List[RawLap]): Unit \ Console =
        CarRow.disagreements(rawLaps)
            |> List.forEach(d -> Console.eprintln(
                "${task#entry#id}: [car ${d#carNumber} #${d#lapNumber}] car-description: "
                    + "${d#field} kept=\"${d#kept}\" found=\"${d#found}\""));
        CarDrivers.disagreements(rawLaps)
            |> List.forEach(d -> Console.eprintln(
                "${task#entry#id}: [car ${d#carNumber} #${d#lapNumber}] seat-${d#driverNumber}: "
                    + "kept=\"${d#kept}\" found=\"${d#found}\""))

    /// The worklist and `rounds` are both the calendar, so a task with no row
    /// is a run that wrote the two from different lists; a seat whose name the
    /// same run did not number is the same fault a step later.
    ///
    /// The timeline is counted off the laps this just sent, so it goes last and
    /// reads back inside the round's own savepoint, as the rules do.
    def load(
        rounds: List[RoundRow],
        numbering: Numbered,
        newDrivers: List[Drivers.DriverRow],
        newEntries: List[Entries.EntryRow],
        seats: List[CarDrivers.Seat],
        task: FileTask.FileTask,
        rawLaps: List[RawLap]
    ): Loaded \ Db =
        match Rounds.idIn(rounds, task#entry) {
            case None => DbErr.fail(Db.Error.Incomplete(
                "round ${FileTask.label(task)} has no row in ${Rounds.table()}"))
            case Some(roundId) =>
                discard Drivers.insertRows(newDrivers);
                let entries = Entries.insertRows(newEntries);
                match CarDrivers.fromSeats(roundId, numbering#drivers, seats) {
                    case None => DbErr.fail(Db.Error.Incomplete(
                        "round ${FileTask.label(task)} names a driver the run did not number"))
                    case Some(seatRows) =>
                        let seatCount = CarDrivers.insertRows(seatRows);
                        match CarRow.fromRawLaps(
                                roundId, task#entry#season, numbering#entries, rawLaps) {
                            case None => DbErr.fail(Db.Error.Incomplete(
                                "round ${FileTask.label(task)} names a car the run did not number"))
                            case Some(carRows) =>
                                let cars = Cars.insertRows(carRows);
                                let laps = Laps.insertRows(LapRow.fromRawLaps(roundId, rawLaps));
                                let events = timeline(roundId, task#entry);
                                { entries = entries, cars = cars, seats = seatCount,
                                  laps = laps, events = events }
                        }
                }
        }

    def timeline(roundId: Int32, entry: Motorsport.Calendar.Entry): Int32 \ Db =
        TimelineEvents.insertRows(TimelineEvents.fromEvents(
            roundId,
            Round.Timeline.fromLaps(entry, Round.Summary.particulars(entry)#timeLimit)
        ))

    /// As `reportDisagreements`, across the rounds of one season rather than
    /// within one round: the first round to name an entry describes it, and a
    /// later round describing it otherwise reaches no column.
    def reportEntryDisagreements(
        task: FileTask.FileTask,
        differing: List[Entries.Disagreement]
    ): Unit \ Console =
        differing |> List.forEach(d -> Console.eprintln(
            "${task#entry#id}: [car ${d#carNumber}] season-${d#season} entry: "
                + "${d#field} kept=\"${d#kept}\" found=\"${d#found}\""))

    def reportViolations(task: FileTask.FileTask, loaded: Loaded): Loaded \ {Console, DbRead} =
        Validation.validate(task#entry) |> List.forEach(Console.eprintln);
        loaded

}
