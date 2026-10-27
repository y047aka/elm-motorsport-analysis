/// Whether a circuit's timing lines still stand where they were put a season
/// earlier, read off the timing feed of two rounds run at the same circuit.
///
///     nix run .#geometry-timing-lines -- 2026/cota_6h --against 2025
///
/// The feed holds times, so the lines are inferred from them: each class's
/// fastest sector, as a share of the fastest lap the same class could make, is
/// read as a share of the distance round the lap. A sector's time is not
/// proportional to the ground it covers -- that ground is a mixture of corners and
/// straights -- and the fastest Hypercar laps put the first line some 170 m from
/// where the circuit's own map draws it. So the shares are printed beside the
/// map's lines and never judged against them; what is judged against the distance
/// allowed is the season-to-season difference, since both readings carry that
/// error of the method -- a line the organisers moved would show as hundreds of
/// metres, and a changed Balance of Performance or a new tyre costs tens.
///
/// The map's lines are `Motorsport.Circuit`'s, and the reading of the feed is the
/// summary's: `Round.Summary`'s `fastestSectors` asks the database the same
/// question of the same rows.
///
/// Where a share places a line against the drawn shape itself is not asked here,
/// and `circuits/README.md` holds why the reading stops short of it;
/// `.#geometry -- regenerate` and `.#geometry -- diff` are the readers that measure the
/// geometry.
pub mod Cli.TimingLines {

    use Cli.Args.Outcome
    use Cli.Errors.CliError
    use Cli.TimingLines.Feed.{
        CircuitMap, Column, Fastest, Line, Movement, Placement, decode, fastestSectors,
        impliedLines, metres, movedMetres, movement, percent, placesOf, publishedLines,
        count, seconds, sectors, sectorsOf, sharesOf, speeds, table
    }
    use Motorsport.Circuit.Circuit
    use Motorsport.Circuit.PublishedMap
    use Motorsport.Circuit.TimingMap
    use Motorsport.Events
    use Sys.Console
    use Report.Files

    /// How far round the lap one line implied one season may sit from the same
    /// line implied the season after before the two are said to stand on
    /// different lines. What set it is the two rounds of the Circuit of the
    /// Americas there are: their fastest sectors imply lines 28.3 m apart at the
    /// widest class, and a line the series actually moved would land hundreds of
    /// metres away.
    pub def defaultTolerance(): Float64 = 40.0

    /// What the report is asked for: the round to read, the season to read it against,
    /// how far round the lap one line may come to stand between the two readings, and the
    /// directory the feeds are in. The `timing-lines` word parses it out of its flags --
    /// see `Report` -- and hands it over whole.
    pub type alias Request = {
        csv       = String,
        season    = Int32,
        id        = String,
        against   = Option[Int32],
        tolerance = Float64
    }

    /// One season read: what each class was fastest at, and where round the lap
    /// that implies the lines stand.
    type alias Reading = {
        season = Int32,
        id = String,
        path = String,
        laps = Int32,
        fastest = List[Fastest],
        positions = List[Placement]
    }

    /// The circuit's map and the seasons read against it, in the order the reader
    /// named them -- the later season first, since the question is whether the
    /// lines still stand where they stood. What the run was asked for travels with the
    /// readings, since the distance allowed is a reader's flag and no figure the readings
    /// say for themselves.
    type alias Report = {
        circuit = Circuit,
        lines = List[Line],
        lapLength = Float64,
        readings = List[Reading],
        asked = Request
    }

    /// The report read, printed and judged: `Err` is a reading that never happened,
    /// and the outcome is the verdict the readings came to — 1 where a line stands
    /// further round the lap than the distance allowed, which is the answer that
    /// the two seasons were not run on one map. One reading alone is printed and
    /// exits 0: nothing was judged.
    pub def runAll(asked: Request): Result[CliError, Outcome] \ {IO, Console} =
        match read(asked) {
            case Err(problem) => Err(problem)
            case Ok(report) =>
                printReadings(report);
                Ok(judge(report))
        }

    /// Where the circuit's own map puts its lines, and the two rounds' feeds read
    /// against it.
    def read(asked: Request): Result[CliError, Report] \ IO =
        match forM(
            circuit   <- circuitOf(asked#id);
            published <- publishedMap(asked, circuit);
            lines     <- linesOf(published)
        ) yield (circuit, published, lines) {
            case Err(problem)                  => Err(problem)
            case Ok((circuit, published, lines)) =>
                let circuitMap = { lapLength = published#lapLength, lines = lines };
                Result.map(
                    readings -> {
                        circuit = circuit,
                        lines = circuitMap#lines,
                        lapLength = circuitMap#lapLength,
                        readings = readings,
                        asked = asked
                    },
                    Result.traverse(readRound(circuitMap, asked), seasonsOf(asked))
                )
        }

    def circuitOf(id: String): Result[CliError, Circuit] =
        Option.toOk(
            CliError.Reading(
                "${id} is run on no circuit this knows: Motorsport.Events.circuit says which ground a round was run on."
            ),
            Events.circuit(id)
        )

    /// The circuit's published map, or why this is not a question it can answer.
    ///
    /// A circuit the organiser re-maps every year is refused rather than read:
    /// the question -- do one map's lines still stand a season later -- has no
    /// answer where there is no such thing as one map.
    def publishedMap(asked: Request, circuit: Circuit): Result[CliError, PublishedMap] =
        match Motorsport.Circuit.timingMap(circuit) {
            case TimingMap.Published(published) => Ok(published)
            case TimingMap.PerSeason(reason)    =>
                Err(CliError.Reading(
                    "${asked#season}/${asked#id} is run on a circuit whose timing map is not one set of lines: ${reason}."
                ))
            case TimingMap.Unsurveyed =>
                Err(CliError.Reading(
                    "no timing map is published for ${asked#season}/${asked#id}: circuits/ surveys the lines of only some circuits, and this circuit is not one of them."
                ))
        }

    /// The intermediate lines the published stretches imply. The stretches are
    /// trusted with the lap length they add up to and with nothing else: the
    /// shares place a line some 170 m from these, by the method's own error, and
    /// that says nothing about a mistake here.
    def linesOf(published: PublishedMap): Result[CliError, List[Line]] =
        publishedLines(published#stretches, published#lapLength)

    /// The seasons read: the round's own first, then the one named against it, since what
    /// is judged is whether the lines still stand where they stood a season earlier.
    def seasonsOf(asked: Request): List[Int32] =
        match asked#against {
            case None        => asked#season :: Nil
            case Some(other) => asked#season :: other :: Nil
        }

    /// One season of one round: how fast each class went round each sector, and
    /// where round the lap that implies the lines stand.
    def readRound(circuitMap: CircuitMap, asked: Request, season: Int32): Result[CliError, Reading] \ IO =
        let path = "${asked#csv}/${season}/${asked#id}.csv";
        forM(
            lines   <- readCsv(path);
            rows    <- decode(path, List.join("\n", lines));
            fastest <- fastestSectors(rows)
        ) yield {
            season = season,
            id = asked#id,
            path = path,
            laps = List.length(rows),
            fastest = fastest,
            positions = impliedLines(fastest, circuitMap)
        }

    /// The feed's lines. A season that was never run at this circuit is a mistake
    /// a reader makes by hand, and is answered as one rather than as a race that
    /// ran no laps.
    def readCsv(path: String): Result[CliError, List[String]] \ IO =
        forM(
            exists <- Files.exists(path) |> Result.mapErr(CliError.File);
            lines  <- if (exists)
                          Files.readLines(path) |> Result.mapErr(CliError.File)
                      else
                          Err(CliError.Reading("there is no ${path} to read: the feed sits under <csv>/<season>/<id>.csv."))
        ) yield lines

    // ---------------------------------------------------------------- printing

    /// The map's lines round the lap, then one table per season.
    def printReadings(report: Report): Unit \ Console = {
        let columns = columnsOf(report#lines);
        Console.println(mapLine(report));
        List.forEach(printRound(columns, report), report#readings)
    }

    /// Where the circuit's own map puts its lines, spelled as the map spells
    /// them.
    def mapLine(report: Report): String =
        let placed = List.map(line -> "${line#id} at ${metres(line#metres)} m", report#lines);
        let lap = "lap at ${metres(report#lapLength)} m";
        "The lines ${Motorsport.Circuit.jsonValue(report#circuit)} is drawn on: ${List.join(", ", placed ++ (lap :: Nil))}."

    /// The table's columns: the class, each sector's fastest time and share, each
    /// intermediate line's implied position under the name the map gives it, and
    /// the mean speed the published stretches work out to.
    pub def columnsOf(lines: List[Line]): List[Column] =
        ({ name = "class", width = 12 } :: Nil)
            ++ sectorColumns(sector -> "${sector} time", 9)
            ++ sectorColumns(sector -> "${sector} %", 8)
            ++ List.map(line -> { name = "${line#id} m", width = 11 }, lines)
            ++ sectorColumns(sector -> "${sector} km/h", 9)

    /// The three sector columns, under one label each.
    def sectorColumns(label: String -> String, width: Int32): List[Column] =
        List.map(sector -> { name = label(sector), width = width }, sectors())

    def printRound(columns: List[Column], report: Report, reading: Reading): Unit \ Console = {
        Console.println("");
        Console.println("${reading#season}/${reading#id}: ${count(reading#laps)} laps of ${reading#path}");
        Console.println(table(columns, List.map(column -> column#name, columns)));
        List.forEach(printLap(columns, report), reading#fastest)
    }

    def printLap(columns: List[Column], report: Report, each: Fastest): Unit \ Console =
        Console.println(table(columns, rowOf(mapOf(report), each)))

    /// The map the readings were placed against, which every row of the table is
    /// printed against too.
    def mapOf(report: Report): CircuitMap =
        { lapLength = report#lapLength, lines = report#lines }

    /// One class's row: its fastest sectors, what share of its own best lap each
    /// is, where those shares place the map's lines, and how fast it went over
    /// each stretch, km/h. The field whole is printed as one more class, which is
    /// how the shares the export carries are counted.
    def rowOf(circuitMap: CircuitMap, each: Fastest): List[String] =
        let times = each#times;
        (each#carClass :: Nil)
            ++ List.map(seconds, sectorsOf(times))
            ++ List.map(percent, sharesOf(times))
            ++ List.map(metres, placesOf(times, circuitMap))
            ++ speeds(times, circuitMap)

    // ---------------------------------------------------------------- judging

    /// The two seasons laid against each other, and the verdict the reader came
    /// for.
    def judge(report: Report): Outcome \ Console =
        match report#readings {
            case first :: second :: _ =>
                let shift = movement(first#positions, second#positions);
                let columns = ({ name = "class", width = 12 } :: Nil)
                    ++ List.map(line -> { name = line#id, width = 11 }, report#lines);
                Console.println("");
                Console.println("${first#season} against ${second#season}: how far round the lap one line stands");
                Console.println(table(columns, List.map(column -> column#name, columns)));
                List.forEach(
                    each -> Console.println(table(columns, (each#carClass :: Nil) ++ List.map(movedMetres, each#positions))),
                    shift#compared
                );
                List.forEach(
                    name -> Console.println("${name} ran in one season only, so its lines are not compared."),
                    shift#oneSeasonOnly
                );
                verdict(shift, report, first#season, second#season)
            case one :: Nil =>
                Outcome.Done(
                    ""
                        :: "${one#season}/${one#id} is read against no other season: --against names one, and only two readings can be judged apart."
                        :: Nil
                )
            case Nil =>
                // Reached by no run: `read` traverses `seasonsOf`, which always
                // holds the round's own season, and fails before printing if
                // that feed cannot be read.
                Outcome.Failed("no season was read, so no line was judged")
        }

    /// Whether the two readings stand on one map of the circuit: the distance
    /// allowed is what answers it, and the answer is printed rather than judged by
    /// the reader.
    def verdict(shift: Movement, report: Report, season: Int32, against: Int32): Outcome =
        let allowed = report#asked#tolerance;
        if (shift#furthest > allowed)
            Outcome.Verdict(
                ""
                    :: "${metres(shift#furthest)} m is over the ${metres(allowed)} m allowed: ${season} and ${against} are far enough apart to read a map of the later one and place the lines by season, as Le Mans's are."
                    :: Nil
            )
        else
            Outcome.Done(
                ""
                    :: "Within the ${metres(allowed)} m allowed -- ${percent(shift#furthest / report#lapLength)} of a lap: one set of lines answers for ${season} and ${against}."
                    :: Nil
            )

}
