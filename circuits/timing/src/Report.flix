/// What `nix run .#geometry-timing-lines` is asked for: the round to read, the
/// season to read it against, how far round the lap one line may come to stand
/// between the two readings, and the directory the feeds are in.
///
/// Written over `Util.GetOpt` as `Cli.Args` is, so that one style of `--help`
/// answers in this repository. `--load`, `--export`, `--serve`, `--port` and
/// `--database` are refused rather than ignored: they belong to the CLI's other
/// commands, which compute in a database.
///
/// Nothing here opens a file. The distance allowed defaults to
/// `Cli.TimingLines.defaultTolerance`, the command that reads it and says what it
/// is judged against, and the round is checked against `Motorsport.Calendar`
/// rather than against four digits a reader types.
pub mod Report {

    use Util.GetOpt.ArgDescr
    use Util.GetOpt.OptionDescr
    use Cli.Errors.CliError
    use Cli.Errors.checkDirectory
    use Motorsport.Calendar
    use Sys.Console

    /// The round and its season -- the `Motorsport.Calendar` entry's own season,
    /// which names the directory its feed is in -- the season laid beside it, the
    /// distance allowed, and where the feeds are.
    pub type alias Request = {
        csv = String,
        season = Int32,
        id = String,
        against = Option[Int32],
        tolerance = Float64
    }

    /// The arguments as given, when they are not what the report reads. Derived,
    /// as `Cli.Args.ArgsError` is, so that the flag which was wrong is named in
    /// what the reader sees rather than in a stack trace.
    pub enum ReportError with ToString {
        case MissingDirectory(String)
        case UnexpectedArguments(List[String])
        case ParseErrors(List[String])
    }

    enum Setting {
        case Csv(String)
        case Against(String)
        case Tolerance(String)
    }

    /// The exit code the arguments come to: 1 for arguments which cannot be read
    /// or a feed directory which is not there, and whatever the report itself
    /// says -- 1 from the report also being an answer, the distance having been
    /// exceeded.
    pub def exitCode(args: List[String]): Int32 \ { IO, Console } =
        match parse(args) {
            case Err(e) =>
                Console.eprintln("Error: ${e}");
                Console.eprintln(usage());
                1
            case Ok(request) => feed(request)
        }

    /// The feeds are read out of a directory, so a report given one which is not
    /// there says so rather than reporting no laps.
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

    pub def parse(args: List[String]): Result[ReportError, Request] =
        match Util.GetOpt.getOpt(Util.GetOpt.ArgOrder.Permute, optionDescrs(), args) {
            case Validation.Failure(errors) => Err(ReportError.ParseErrors(Nec.toList(errors)))
            case Validation.Success(result) => requestOf(result#options, result#nonOptions)
        }

    def requestOf(settings: List[Setting], nonOptions: List[String]): Result[ReportError, Request] =
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

    /// A report reads its feeds out of a directory, so one given none has nowhere
    /// to look.
    def required(name: String, dir: Option[String]): Result[ReportError, String] =
        Option.toOk(ReportError.MissingDirectory("--${name}"), dir)

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

    def namedRound(nonOptions: List[String]): Result[ReportError, Named] =
        match nonOptions {
            case only :: Nil =>
                match roundName(only) {
                    case Some((season, id)) => Ok({ season = season, id = id })
                    case None               =>
                        Err(ReportError.ParseErrors("\"${only}\" names no round: name one as <season>/<id>, like 2026/cota_6h." :: Nil))
                }
            case Nil    => Err(ReportError.ParseErrors("the report reads one round, named as <season>/<id>." :: Nil))
            case extras => Err(ReportError.UnexpectedArguments(extras))
        }

    def roundName(name: String): Option[(Int32, String)] =
        match String.splitOn({substr = "/"}, name) {
            case season :: id :: Nil =>
                Int32.fromString(season)
                    |> Option.flatMap(year -> Calendar.find(year, id))
                    |> Option.map(entry -> (entry#season, entry#id))
            case _ => None
        }

    /// The last `--against` wins, as the last `--database` does in the CLI. A
    /// season is read as an integer and not checked against `Motorsport.Calendar`:
    /// the directory that is not there is named by the report itself, which is the
    /// one place that knows whether a season ran this round.
    def againstSeason(settings: List[Setting]): Result[ReportError, Option[Int32]] =
        match last(seasonNamed, settings) {
            case None       => Ok(None)
            case Some(name) =>
                // Four digits, because the calendar's seasons are spelled that way and a
                // reader typing `24` means a season and not twenty-four AD. Whether that
                // season ran this round is the report's to find out, since it is the one
                // place that looks in the directory.
                match Int32.fromString(name) {
                    case Some(season) =>
                        if (String.length(name) == 4)
                            Ok(Some(season))
                        else
                            Err(ReportError.ParseErrors("\"${name}\" is not a season: --against names a year, like 2025." :: Nil))
                    case None =>
                        Err(ReportError.ParseErrors("\"${name}\" is not a season: --against names a year, like 2025." :: Nil))
                }
        }

    /// The distance allowed, defaulting to the report's own and refusing nought:
    /// a run that allows no distance calls every two seasons run on different
    /// lines, which is the one answer nobody came for.
    def distanceAllowed(settings: List[Setting]): Result[ReportError, Float64] =
        match last(toleranceNamed, settings) {
            case None          => Ok(Cli.TimingLines.defaultTolerance())
            case Some(spelled) =>
                match Float64.fromString(spelled) {
                    case Some(metres) =>
                        if (metres > 0.0)
                            Ok(metres)
                        else
                            Err(ReportError.ParseErrors("\"${spelled}\" is not a distance: --tolerance is metres, and more than nought." :: Nil))
                    case None =>
                        Err(ReportError.ParseErrors("\"${spelled}\" is not a distance: --tolerance is metres, and more than nought." :: Nil))
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

    /// The last answer to a repeated option, which is the one the reader meant.
    def last(asking: Setting -> Option[String], settings: List[Setting]): Option[String] =
        List.foldLeft(
            (acc, setting) -> {
                let asked = asking(setting);
                match asked {
                    case None    => acc
                    case Some(_) => asked
                }
            },
            None,
            settings
        )

    pub def usage(): String =
        Util.GetOpt.usageInfo(
            "Usage: geometry-timing-lines --csv <dir> <season>/<id> [--against <season>] [--tolerance <metres>]",
            optionDescrs()
        )

}
