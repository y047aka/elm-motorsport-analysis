/// What `nix run .#geometry-timing-lines` is asked for: the round to read, the
/// season to read it against, how far round the lap one line may come to stand
/// between the two readings, and the directory the feeds are in.
///
/// Runs on the shared `Cli.Args` scan and answering, as every other word does,
/// so a wrong flag is answered with one style of usage at either command.
/// `--load`, `--export`, `--serve`, `--port` and `--database` are refused: they
/// belong to the CLI's other commands, which compute in a database. Nothing
/// here opens a file.
pub mod Report {

    use Util.GetOpt.ArgDescr
    use Util.GetOpt.OptionDescr
    use Cli.Args.ArgsError
    use Cli.Errors.checkDirectory
    use Motorsport.Calendar
    use Sys.Console

    /// The round and its season -- the `Motorsport.Calendar` entry's own season,
    /// which names the directory its feed is in -- and what to judge against.
    pub type alias Request = {
        csv = String,
        season = Int32,
        id = String,
        against = Option[Int32],
        tolerance = Float64
    }

    enum Setting with Eq {
        case Help
        case Csv(String)
        case Against(String)
        case Tolerance(String)
    }

    /// The exit code the arguments come to. 1 is an answer the report gives as
    /// well: a line standing further round the lap than the distance allowed.
    pub def exitCode(args: List[String]): Int32 \ { IO, Console } =
        Cli.Args.answer(
            optionDescrs(),
            usage(),
            isHelp,
            args,
            scanned -> requestOf(scanned#options, scanned#words),
            feed
        )

    def feed(request: Request): Int32 \ { IO, Console } =
        match checkDirectory(request#csv) {
            case Err(e) =>
                Console.eprintln("Error: ${e}");
                1
            case Ok(()) =>
                Cli.TimingLines.runAll(
                    request#csv,
                    request#season,
                    request#id,
                    request#against,
                    request#tolerance
                )
        }

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
            explanation   = "how far round the lap one line may stand apart\nin the two readings (default ${Cli.TimingLines.defaultTolerance()} m)"
        } :: Nil

    def isHelp(setting: Setting): Bool =
        setting == Setting.Help

    pub def parse(args: List[String]): Result[ArgsError, Request] =
        match Cli.Args.scan(optionDescrs(), args) {
            case Err(problem) => Err(problem)
            case Ok(scanned)  => requestOf(scanned#options, scanned#words)
        }

    def requestOf(settings: List[Setting], nonOptions: List[String]): Result[ArgsError, Request] =
        forM(
            csv       <- required("csv", csvDir(settings));
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

    def csvDir(settings: List[Setting]): Option[String] =
        settings |> List.foldLeft((acc, setting) -> match setting {
            case Setting.Csv(dir) => Some(dir)
            case _                => acc
        }, None)

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

    /// The last `--against` wins, as the last `--database` does in the CLI.
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
            case None          => Ok(Cli.TimingLines.defaultTolerance())
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

    pub def usage(): String =
        Util.GetOpt.usageInfo(
            "usage: nix run .#geometry -- timing-lines --csv <dir> <season>/<id> [--against <season>] [--tolerance <metres>]",
            optionDescrs()
        )

}
