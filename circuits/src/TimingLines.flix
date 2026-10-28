/// Whether a circuit's timing lines still stand where they were put a season earlier,
/// read off the timing feed of two rounds run at the same circuit: the word that
/// `nix run .#geometry-timing-lines` is — its flags, its readings, its printing and the
/// exit code they come to.
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
///
/// The readings of the feed -- rows, shares, placements, the columns they print in --
/// are `TimingLines.Feed`'s, and reach no file at all; the file is opened through
/// `TimingLines.Files`, which resolves no path, since the directory a reader named is
/// where the feeds sit. `--load`, `--export`, `--serve`, `--port` and `--database` are
/// refused: they belong to the CLI's other words, which compute in a database. Nothing
/// here computes in one, and nothing here lays a file down.
pub mod TimingLines {

    use Cli.Args.ArgsError
    use Cli.Args.Outcome
    use Cli.Errors.checkDirectory
    use Cli.Errors.CliError
    use Motorsport.Calendar
    use Motorsport.Circuit.Circuit
    use Motorsport.Circuit.PublishedMap
    use Motorsport.Circuit.TimingMap
    use Motorsport.Events
    use Sys.Console
    use TimingLines.Feed.{
        CircuitMap, Column, Fastest, Line, Movement, Placement, decode, fastestSectors,
        impliedLines, metres, movedMetres, movement, percent, placesOf, publishedLines,
        count, seconds, sectors, sectorsOf, sharesOf, speeds, table
    }
    use TimingLines.Files
    use Util.GetOpt.ArgDescr
    use Util.GetOpt.OptionDescr

    /// How far round the lap one line implied one season may sit from the same
    /// line implied the season after before the two are said to stand on
    /// different lines. What set it is the two rounds of the Circuit of the
    /// Americas there are: their fastest sectors imply lines 28.3 m apart at the
    /// widest class, and a line the series actually moved would land hundreds of
    /// metres away.
    pub def defaultTolerance(): Float64 = 40.0

    /// What the report is asked for: the round to read, the season to read it against,
    /// how far round the lap one line may come to stand between the two readings, and the
    /// directory the feeds are in.
    pub type alias Request = {
        csv       = String,
        season    = Int32,
        id        = String,
        against   = Option[Int32],
        tolerance = Float64
    }

    enum Setting with Eq {
        case Help
        case Csv(String)
        case Against(String)
        case Tolerance(String)
    }

    pub def usage(): String =
        Util.GetOpt.usageInfo(
            "usage: nix run .#geometry -- timing-lines --csv <dir> <season>/<id> [--against <season>] [--tolerance <metres>]",
            optionDescrs()
        )

    def optionDescrs(): List[OptionDescr[Setting]] =
        Cli.Args.helpDescr(Setting.Help) ::
        {
            optionIds     = Nil,
            optionNames   = "csv" :: Nil,
            argDescriptor = ArgDescr.ReqArg(dir -> Some(Setting.Csv(dir)), "DIR"),
            explanation   = "the directory holding the season directories\nof CSV"
        } ::
        {
            optionIds     = Nil,
            optionNames   = "against" :: Nil,
            argDescriptor = ArgDescr.ReqArg(season -> Some(Setting.Against(season)), "SEASON"),
            explanation   = "read the round against this season as well"
        } ::
        {
            optionIds     = Nil,
            optionNames   = "tolerance" :: Nil,
            argDescriptor = ArgDescr.ReqArg(metres -> Some(Setting.Tolerance(metres)), "METRES"),
            explanation   = "how far round the lap one line may stand apart\nin the two readings (default ${defaultTolerance()} m)"
        } :: Nil

    def isHelp(setting: Setting): Bool =
        setting == Setting.Help

    pub def parse(args: List[String]): Result[ArgsError, Request] =
        match Cli.Args.scan(optionDescrs(), args) {
            case Err(problem) => Err(problem)
            case Ok(scanned)  => completed(scanned)
        }

    def completed(scanned: Cli.Args.Scanned[Setting]): Result[ArgsError, Request] =
        complete(scanned#options, scanned#words)

    def complete(settings: List[Setting], nonOptions: List[String]): Result[ArgsError, Request] =
        forM(
            csv       <- required("csv", Cli.Args.lastNamed(csvNamed, settings));
            named     <- namedRound(nonOptions);
            against   <- againstSeason(settings);
            tolerance <- distanceAllowed(settings)
        ) yield {
            csv = csv,
            season = named#season,
            id = named#id,
            against = against,
            tolerance = tolerance
        }

    def required(name: String, dir: Option[String]): Result[ArgsError, String] =
        Option.toOk(ArgsError.ParseErrors("--${name} is required: the feed sits in the season directories under it." :: Nil), dir)

    def csvNamed(setting: Setting): Option[String] =
        match setting {
            case Setting.Csv(dir) => Some(dir)
            case _                => None
        }

    /// One round named outright, and named as one on the calendar: the season
    /// directory a feed is read out of is a season the championship ran, not any
    /// four digits a reader types.
    type alias Named = {
        season = Int32,
        id = String
    }

    def namedRound(nonOptions: List[String]): Result[ArgsError, Named] =
        match nonOptions {
            case only :: Nil =>
                match roundName(only) {
                    case Some((season, id)) => Ok({ season = season, id = id })
                    case None               =>
                        Err(ArgsError.ParseErrors("\"${only}\" names no round: name one as <season>/<id>, like 2026/cota_6h." :: Nil))
                }
            case Nil    => Err(ArgsError.ParseErrors("the report reads one round, named as <season>/<id>." :: Nil))
            case extras => Err(ArgsError.ParseErrors("${List.join(", ", extras)} are not arguments this report reads, which names one round as <season>/<id>." :: Nil))
        }

    def roundName(name: String): Option[(Int32, String)] =
        match String.splitOn({substr = "/"}, name) {
            case season :: id :: Nil =>
                Int32.fromString(season)
                    |> Option.flatMap(year -> Calendar.find(year, id))
                    |> Option.map(entry -> (entry#season, entry#id))
            case _ => None
        }

    /// The last `--against` wins, as a repeated option usually does.
    def againstSeason(settings: List[Setting]): Result[ArgsError, Option[Int32]] =
        match Cli.Args.lastNamed(seasonNamed, settings) {
            case None       => Ok(None)
            case Some(name) =>
                // Four digits, because the calendar's seasons are spelled that
                // way and a reader typing `24` means a season and not
                // twenty-four AD.
                match Int32.fromString(name) {
                    case Some(season) =>
                        if (String.length(name) == 4)
                            Ok(Some(season))
                        else
                            Err(ArgsError.ParseErrors("\"${name}\" is not a season: --against names a year, like 2025." :: Nil))
                    case None =>
                        Err(ArgsError.ParseErrors("\"${name}\" is not a season: --against names a year, like 2025." :: Nil))
                }
        }

    /// The distance allowed, defaulting to the report's own and refusing nought:
    /// a run that allows no distance calls every two seasons run on different lines.
    def distanceAllowed(settings: List[Setting]): Result[ArgsError, Float64] =
        match Cli.Args.lastNamed(toleranceNamed, settings) {
            case None          => Ok(defaultTolerance())
            case Some(spelled) =>
                match Float64.fromString(spelled) {
                    case Some(metres) =>
                        if (metres > 0.0)
                            Ok(metres)
                        else
                            Err(ArgsError.ParseErrors("\"${spelled}\" is not a distance: --tolerance is metres, and more than nought." :: Nil))
                    case None =>
                        Err(ArgsError.ParseErrors("\"${spelled}\" is not a distance: --tolerance is metres, and more than nought." :: Nil))
                }
        }

    def seasonNamed(setting: Setting): Option[String] =
        match setting {
            case Setting.Against(name) => Some(name)
            case _                     => None
        }

    def toleranceNamed(setting: Setting): Option[String] =
        match setting {
            case Setting.Tolerance(metres) => Some(metres)
            case _                         => None
        }

    // ------------------------------------------------------------------- the command

    /// The exit code the arguments come to. 1 is an answer the report gives as
    /// well: a line standing further round the lap than the distance allowed.
    pub def exitCode(args: List[String]): Int32 \ { IO, Console } =
        Cli.Args.comeTo(arguments(args), asking)

    /// The arguments as far as the flag table reads them, before the report asks
    /// which round on the calendar was named.
    pub def arguments(args: List[String]): Cli.Args.Parsed[Request] =
        Cli.Args.prepare(optionDescrs(), usage(), isHelp, completed, args)

    /// The directory the feeds sit in, asked once, and then the two rounds read and
    /// judged: a mistyped `--csv` is one mistake rather than every race missing.
    def asking(request: Request): Outcome \ { IO, Console } =
        Cli.Args.outcomeOf(
            forM(
                _       <- checkDirectory(request#csv);
                verdict <- judged(request)
            ) yield verdict
        )

    /// The report read, printed and judged, in the words the report says its own
    /// readings failed in. `Err` is a reading that never happened, and the outcome
    /// is the verdict the readings came to — 1 where a line stands further round
    /// the lap than the distance allowed, which is the answer that the two seasons
    /// were not run on one map. One reading alone is printed and exits 0: nothing
    /// was judged.
    def judged(request: Request): Result[CliError, Outcome] \ { IO, Console } =
        read(request)
            |> Result.flatMap(report -> {
                printReadings(report);
                Ok(judge(report))
            })

    // ------------------------------------------------------------------ the readings

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

    /// Where the circuit's own map puts its lines, and the two rounds' feeds read
    /// against it.
    def read(asked: Request): Result[CliError, Report] \ IO =
        match forM(
            circuit   <- circuitOf(asked#id);
            published <- publishedMap(asked, circuit);
            lines     <- linesOf(published)
        ) yield (circuit, published, lines) {
            case Err(problem)                    => Err(problem)
            case Ok((circuit, published, lines)) =>
                let circuitMap = { lapLength = published#lapLength, lines = lines };
                seasonsOf(asked)
                    |> Result.traverse(readRound(circuitMap, asked))
                    |> Result.map(readings -> {
                        circuit = circuit,
                        lines = circuitMap#lines,
                        lapLength = circuitMap#lapLength,
                        readings = readings,
                        asked = asked
                    })
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

    // --------------------------------------------------------------------- printing

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

    // -------------------------------------------------------------------- judging

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
