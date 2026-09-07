mod Cli.Load {

    use Db.CarDrivers
    use Db.Cars
    use Db.Drivers
    use Db.Numbering.Numbering
    use Db.Laps
    use Db.Manufacturers
    use Db.Rounds
    use Db.Rounds.RoundRow
    use Db.Teams

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

    /// What the run has numbered so far. The three are carried between rounds
    /// for one reason: a name turns up in several of them, and the pass that
    /// writes a round cannot read back what no later pass has written.
    type alias Numbered = {
        drivers       = Numbering,
        teams         = Numbering,
        manufacturers = Numbering
    }

    def nothingNumbered(): Numbered = {
        drivers       = Db.Numbering.none(),
        teams         = Db.Numbering.none(),
        manufacturers = Db.Numbering.none()
    }

    /// What the round put in each table, which is what the database took
    /// rather than what the file decoded to.
    type alias Loaded = {
        cars = Int32,
        seats = Int32,
        laps = Int32
    }

    /// The rows a round adds to the tables keyed by a name.
    type alias Added = {
        drivers       = List[Db.Drivers.DriverRow],
        teams         = List[Db.Teams.TeamRow],
        manufacturers = List[Db.Manufacturers.ManufacturerRow]
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
        Teams.create();
        Manufacturers.create();
        CarDrivers.create();
        Cars.create();
        Laps.create();
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
                        + " ${loaded#cars} cars, ${loaded#seats} seats loaded");
                    { processed = acc#processed + 1, numbered = numbered | acc }
                case (Err(e), numbered) =>
                    Console.eprintln("${FileTask.label(task)}: ${e}");
                    { errors = acc#errors + 1, numbered = numbered | acc }
            },
            { processed = 0, errors = 0, numbered = nothingNumbered() },
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

    /// The numbering comes back whether the round loaded or not: a round that
    /// failed partway may already have sent its driver rows, and reusing the
    /// numbers it took would be a name written twice under one id.
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
                let cars = CarRow.firstMentions(rawLaps);
                let (drivers, addedDrivers) =
                    Drivers.add(numbering#drivers, seats |> List.map(s -> s#name));
                let (teams, addedTeams) =
                    Teams.add(numbering#teams, cars |> List.map(c -> c#team));
                let (manufacturers, addedManufacturers) =
                    Manufacturers.add(numbering#manufacturers, cars |> List.map(c -> c#manufacturer));
                let numbered = {
                    drivers = drivers, teams = teams, manufacturers = manufacturers
                };
                let added = {
                    drivers = addedDrivers,
                    teams = addedTeams,
                    manufacturers = addedManufacturers
                };
                let outcome = Db.runWithError(() ->
                        reportViolations(task, load(rounds, numbered, added, seats, task, rawLaps)))
                    |> Result.mapErr(CliError.Database);
                (outcome, numbered)
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
    def load(
        rounds: List[RoundRow],
        numbering: Numbered,
        added: Added,
        seats: List[CarDrivers.Seat],
        task: FileTask.FileTask,
        rawLaps: List[RawLap]
    ): Loaded \ DbWrite =
        match Rounds.idIn(rounds, task#entry) {
            case None => DbErr.fail(Db.Error.Incomplete(
                "round ${FileTask.label(task)} has no row in ${Rounds.table()}"))
            case Some(roundId) =>
                discard Drivers.insertRows(added#drivers);
                discard Teams.insertRows(added#teams);
                discard Manufacturers.insertRows(added#manufacturers);
                let seatRows = CarDrivers.fromSeats(roundId, numbering#drivers, seats);
                let carRows = CarRow.fromRawLaps(
                    roundId, numbering#teams, numbering#manufacturers, rawLaps);
                match (seatRows, carRows) {
                    case (Some(theSeats), Some(theCars)) =>
                        let seatCount = CarDrivers.insertRows(theSeats);
                        let cars = Cars.insertRows(theCars);
                        let laps = Laps.insertRows(LapRow.fromRawLaps(roundId, rawLaps));
                        { cars = cars, seats = seatCount, laps = laps }
                    case _ => DbErr.fail(Db.Error.Incomplete(
                        "round ${FileTask.label(task)} names a driver, a team or a"
                            + " manufacturer the run did not number"))
                }
        }

    def reportViolations(task: FileTask.FileTask, loaded: Loaded): Loaded \ {Console, DbRead} =
        Validation.validate(task#entry) |> List.forEach(Console.eprintln);
        loaded

}
