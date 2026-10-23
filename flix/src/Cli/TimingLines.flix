/// Whether a circuit's timing lines still stand where they were put a season
/// earlier, read off the timing feed of two rounds run at the same circuit.
///
///     nix run .#geometry-timing-lines -- 2026/cota_6h --against 2025
///
/// A circuit is drawn on one set of lines, and a new season at that circuit asks
/// whether the lines have moved; this answers it without a map of the later year.
/// The feed holds times, so the lines are inferred from them: each class's
/// fastest sector, as a share of the fastest lap the same class could make, is
/// read as a share of the distance round the lap. A sector's time is not
/// proportional to the ground it covers -- that ground is a mixture of corners and
/// straights -- and the fastest Hypercar laps put the first line some 170 m from
/// where the circuit's own map draws it. So the shares are printed beside the
/// map's lines and never judged against them, and what is judged against the
/// distance allowed is the season-to-season difference: both readings carry that
/// error of the method, a line the organisers moved would show as hundreds of
/// metres, and a changed Balance of Performance or a new tyre costs tens.
///
/// The map's lines are `Motorsport.Circuit`'s, and the reading of the feed is the
/// summary's -- the fastest sector over every lap, which is what
/// `Round.Summary`'s `fastestSectors` asks the database.
///
/// What this cannot answer is where a place the shares imply stands against the
/// drawn line. A drawn line is a surveyed shape, a surveyed shape is a JSON file,
/// and nothing in this project parses JSON -- `Util.Json.Encode` writes and reads
/// nothing. So the shares are judged against the published stretches alone, and
/// how far a drawn line stands from the figures it was laid from is
/// `.#geometry-regenerate`'s and `.#geometry-diff`'s to say. Measured that way,
/// COTA's second line stands 6.7 m off its circuit's own map -- a lap whose
/// sector times are within tolerance of another season's can still be drawn
/// against a line nobody surveyed.
///
/// This opens no database. The flake runs it with neither `--database` nor
/// `DATABASE_URL`, and `runAll`'s effect says the same: it reads the feed and
/// prints.
pub mod Cli.TimingLines {

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
    use Util.Files

    /// How far round the lap one line implied one season may sit from the same
    /// line implied the season after before the two are said to stand on
    /// different lines. What set it is the two rounds of the Circuit of the
    /// Americas there are: their fastest sectors imply lines 28.3 m apart at the
    /// widest class, and a line the series actually moved would land hundreds of
    /// metres away.
    pub def defaultTolerance(): Float64 = 40.0

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
    /// lines still stand where they stood.
    type alias Report = {
        circuit = Circuit,
        lines = List[Line],
        lapLength = Float64,
        readings = List[Reading],
        tolerance = Float64,
        against = Option[Int32]
    }

    /// The report printed, and the code to exit with: 1 where a line stands
    /// further round the lap than the distance allowed, which is the answer that
    /// the two seasons were not run on one map.
    pub def runAll(csv: String, season: Int32, id: String, against: Option[Int32], tolerance: Float64): Int32 \ {IO, Console} =
        match read(csv, season, id, against, tolerance) {
            case Err(problem) =>
                Console.eprintln("Error: ${problem}");
                1
            case Ok(report) =>
                printReadings(report);
                judge(report)
        }

    /// Where the circuit's own map puts its lines, and the two rounds' feeds read
    /// against it.
    def read(csv: String, season: Int32, id: String, against: Option[Int32], tolerance: Float64): Result[CliError, Report] \ IO =
        match forM(
            circuit   <- circuitOf(id);
            published <- publishedMap(season, id, circuit);
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
                        tolerance = tolerance,
                        against = against
                    },
                    Result.traverse(readRound(circuitMap, csv, id), seasonsOf(season, against))
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
    def publishedMap(season: Int32, id: String, circuit: Circuit): Result[CliError, PublishedMap] =
        match Motorsport.Circuit.timingMap(circuit) {
            case TimingMap.Published(published) => Ok(published)
            case TimingMap.PerSeason(reason)    =>
                Err(CliError.Reading(
                    "${season}/${id} is run on a circuit whose timing map is not one set of lines: ${reason}."
                ))
            case TimingMap.Unsurveyed =>
                Err(CliError.Reading(
                    "no timing map is published for ${season}/${id}: circuits/ surveys the lines of only some circuits, and this circuit is not one of them."
                ))
        }

    /// The intermediate lines the published stretches imply. The stretches are
    /// trusted with the lap length they add up to and with nothing else: the
    /// shares place a line some 170 m from these, by the method's own error, and
    /// that says nothing about a mistake here.
    def linesOf(published: PublishedMap): Result[CliError, List[Line]] =
        publishedLines(published#stretches, published#lapLength)

    def seasonsOf(season: Int32, against: Option[Int32]): List[Int32] =
        match against {
            case None        => season :: Nil
            case Some(other) => season :: other :: Nil
        }

    /// One season of one round: how fast each class went round each sector, and
    /// where round the lap that implies the lines stand.
    def readRound(circuitMap: CircuitMap, csv: String, id: String, season: Int32): Result[CliError, Reading] \ IO =
        let path = "${csv}/${season}/${id}.csv";
        forM(
            lines   <- readCsv(path);
            rows    <- decode(path, List.join("\n", lines));
            fastest <- fastestSectors(rows)
        ) yield {
            season = season,
            id = id,
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
    /// them. The circuit's name is not repeated here: `Motorsport.Circuit`'s word
    /// for the circuit is the one name it has in this project.
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
    def judge(report: Report): Int32 \ Console =
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
            case _ => 1
        }

    def verdict(shift: Movement, report: Report, season: Int32, against: Int32): Int32 \ Console =
        if (shift#furthest > report#tolerance) {
            Console.println("");
            Console.println(
                "${metres(shift#furthest)} m is over the ${metres(report#tolerance)} m allowed: ${season} and ${against} are far enough apart to read a map of the later one and place the lines by season, as Le Mans's are."
            );
            1
        } else {
            Console.println("");
            Console.println(
                "Within the ${metres(report#tolerance)} m allowed -- ${percent(shift#furthest / report#lapLength)} of a lap: one set of lines answers for ${season} and ${against}."
            );
            0
        }

}
