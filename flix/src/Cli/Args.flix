pub mod Cli.Args {

    use Util.GetOpt.ArgDescr
    use Util.GetOpt.OptionDescr
    use Cli.FileTask.Rounds
    use Motorsport.Calendar

    pub enum ArgsError with ToString {
        case MissingDirectory(String)
        case UnexpectedArguments(List[String])
        case ParseErrors(List[String])
    }

    /// Converting is the two stages one after the other: the CSV goes into the
    /// rows, and the files are written out of them. `Load` and `Export` are the
    /// same two taken singly, so each takes the one directory it reaches --
    /// `csv` holding the season directories of CSV, `out` the ones the files
    /// are written into. What to convert comes from `Motorsport.Calendar`, so
    /// there is no per-file input and nothing to redirect a single file's
    /// output to. Serving reads the rounds a run has already loaded, so it
    /// takes a database and no directory.
    ///
    /// A stage handed the other stage's directory as well ignores it, as a
    /// load ignores `--export-only`: the flake names both to every converting
    /// run, and a stage flag forwarded to one arrives beside them.
    ///
    /// `exported` narrows the writing stage alone: a round left out of it is
    /// loaded like any other, and `/api` answers for it.
    ///
    /// Reporting the timing lines reads two seasons' CSV and prints, which is why
    /// it takes `csv` like a converting run and no database at all: nothing it
    /// answers is counted in SQL. Its round is named outright rather than taken
    /// from the calendar's whole field, since the question is about one circuit.
    pub enum Command {
        case Convert({ csv = String, out = String, database = Option[String], exported = Rounds })
        case Load({ csv = String, database = Option[String] })
        case Export({ out = String, database = Option[String], exported = Rounds })
        case Serve({ port = Int32, database = Option[String] })
        case TimingLines({
            csv = String,
            season = Int32,
            id = String,
            against = Option[Int32],
            tolerance = Float64
        })
    }

    def defaultPort(): Int32 = 8080

    enum Setting {
        case Database(String)
        case Csv(String)
        case Out(String)
        case Load
        case Export
        case Serve
        case Port(Int32)
        case ExportOnly(String)
        case TimingLines
        case Against(String)
        case Tolerance(String)
    }

    /// Whose owner is `Cli.TimingLines`, which is the command that reads the
    /// distance and says what it is judged against.
    def defaultTolerance(): Float64 = Cli.TimingLines.defaultTolerance()

    def optionDescrs(): List[OptionDescr[Setting]] =
        {
            optionIds     = Nil,
            optionNames   = "database" :: Nil,
            argDescriptor = ArgDescr.ReqArg(url -> Some(Setting.Database(url)), "URL"),
            explanation   = "JDBC URL to compute the run in\n(defaults to DATABASE_URL)"
        } ::
        {
            optionIds     = Nil,
            optionNames   = "csv" :: Nil,
            argDescriptor = ArgDescr.ReqArg(dir -> Some(Setting.Csv(dir)), "DIR"),
            explanation   = "the directory holding the season directories\nof CSV"
        } ::
        {
            optionIds     = Nil,
            optionNames   = "out" :: Nil,
            argDescriptor = ArgDescr.ReqArg(dir -> Some(Setting.Out(dir)), "DIR"),
            explanation   = "the directory the season directories of\nfiles are written into"
        } ::
        {
            optionIds     = Nil,
            optionNames   = "load" :: Nil,
            argDescriptor = ArgDescr.NoArg(Setting.Load),
            explanation   = "read the CSV into the rows without writing\nthe files"
        } ::
        {
            optionIds     = Nil,
            optionNames   = "export" :: Nil,
            argDescriptor = ArgDescr.NoArg(Setting.Export),
            explanation   = "write the files out of the rows without\nreading the CSV"
        } ::
        {
            optionIds     = Nil,
            optionNames   = "serve" :: Nil,
            argDescriptor = ArgDescr.NoArg(Setting.Serve),
            explanation   = "serve the loaded rounds over HTTP instead of converting"
        } ::
        {
            optionIds     = Nil,
            optionNames   = "port" :: Nil,
            argDescriptor = ArgDescr.ReqArg(port -> Option.map(Setting.Port, Int32.fromString(port)), "PORT"),
            explanation   = "port to serve on (default ${defaultPort()})"
        } ::
        {
            optionIds     = Nil,
            optionNames   = "export-only" :: Nil,
            argDescriptor = ArgDescr.ReqArg(name -> Some(Setting.ExportOnly(name)), "SEASON/ID"),
            explanation   = "write this round's files and no other,\nrepeated to name more than one"
        } ::
        {
            optionIds     = Nil,
            optionNames   = "timing-lines" :: Nil,
            argDescriptor = ArgDescr.NoArg(Setting.TimingLines),
            explanation   = "report whether a circuit's timing lines still\nstand where they stood a season earlier"
        } ::
        {
            optionIds     = Nil,
            optionNames   = "against" :: Nil,
            argDescriptor = ArgDescr.ReqArg(season -> Some(Setting.Against(season)), "SEASON"),
            explanation   = "read --timing-lines against this season as well"
        } ::
        {
            optionIds     = Nil,
            optionNames   = "tolerance" :: Nil,
            argDescriptor = ArgDescr.ReqArg(metres -> Some(Setting.Tolerance(metres)), "METRES"),
            explanation   = "how far round the lap one line may stand apart\nin the two readings (default ${defaultTolerance()} m)"
        } :: Nil

    pub def parse(args: List[String]): Result[ArgsError, Command] =
        forM(
            result  <- getOptResult(args);
            command <- toCommand(result#options, result#nonOptions)
        ) yield command

    def toCommand(settings: List[Setting], nonOptions: List[String]): Result[ArgsError, Command] =
        let database = databaseUrl(settings);
        if (serving(settings) and (loading(settings) or exporting(settings)))
            Err(ArgsError.ParseErrors("--serve is not a stage of a converting run" :: Nil))
        else if (serving(settings))
            if (not List.isEmpty(exportOnly(settings)))
                Err(ArgsError.ParseErrors("--export-only is not for --serve" :: Nil))
            else
                match nonOptions {
                    case Nil    => Ok(Command.Serve({ port = port(settings), database = database }))
                    case extras => Err(ArgsError.UnexpectedArguments(extras))
                }
        else if (List.exists(isPort, settings))
            Err(ArgsError.ParseErrors("--port is only for --serve" :: Nil))
        else if (reporting(settings))
            if (loading(settings) or exporting(settings))
                Err(ArgsError.ParseErrors("--timing-lines is a report and not a stage of a converting run" :: Nil))
            else
                reportCommand(settings, nonOptions)
        else if (not List.isEmpty(nonOptions))
            Err(ArgsError.UnexpectedArguments(nonOptions))
        else
            // Naming both stages is naming the run they make up.
            match (loading(settings), exporting(settings)) {
                case (true, false) =>
                    required("csv", csvDir(settings))
                        |> Result.map(csv -> Command.Load({ csv = csv, database = database }))
                case (false, true) =>
                    forM(
                        out      <- required("out", outDir(settings));
                        exported <- exportedRounds(settings)
                    ) yield Command.Export({ out = out, database = database, exported = exported })
                case _ =>
                    forM(
                        csv      <- required("csv", csvDir(settings));
                        out      <- required("out", outDir(settings));
                        exported <- exportedRounds(settings)
                    ) yield Command.Convert({ csv = csv, out = out, database = database, exported = exported })
            }

    /// `Every` unless a run named rounds: an option nobody passed is not a
    /// selection of nothing.
    def exportedRounds(settings: List[Setting]): Result[ArgsError, Rounds] =
        let named = exportOnly(settings);
        if (List.isEmpty(named))
            Ok(Rounds.Every)
        else
            match List.filter(name -> Option.isEmpty(roundName(name)), named) {
                case Nil     => Ok(Rounds.Only(List.filterMap(roundName, named)))
                case unknown =>
                    Err(ArgsError.ParseErrors(unknown |> List.map(name ->
                        "--export-only names no round on the calendar: ${name}")))
            }

    def roundName(name: String): Option[(Int32, String)] =
        match String.splitOn({substr = "/"}, name) {
            case season :: id :: Nil =>
                Int32.fromString(season)
                    |> Option.flatMap(year -> Calendar.find(year, id))
                    |> Option.map(entry -> (entry#season, entry#id))
            case _ => None
        }

    def getOptResult(args: List[String]): Result[ArgsError, {options = List[Setting], nonOptions = List[String]}] =
        match Util.GetOpt.getOpt(Util.GetOpt.ArgOrder.Permute, optionDescrs(), args) {
            case Validation.Failure(errors) => Err(ArgsError.ParseErrors(Nec.toList(errors)))
            case Validation.Success(result) => Ok(result)
        }

    def required(name: String, dir: Option[String]): Result[ArgsError, String] =
        Option.toOk(ArgsError.MissingDirectory("--${name}"), dir)

    def csvDir(settings: List[Setting]): Option[String] =
        settings |> List.foldLeft((acc, setting) -> match setting {
            case Setting.Csv(dir) => Some(dir)
            case _                => acc
        }, None)

    def outDir(settings: List[Setting]): Option[String] =
        settings |> List.foldLeft((acc, setting) -> match setting {
            case Setting.Out(dir) => Some(dir)
            case _                => acc
        }, None)

    def isPort(setting: Setting): Bool =
        match setting {
            case Setting.Port(_) => true
            case _               => false
        }

    def exportOnly(settings: List[Setting]): List[String] =
        settings |> List.filterMap(setting -> match setting {
            case Setting.ExportOnly(name) => Some(name)
            case _                        => None
        })

    def loading(settings: List[Setting]): Bool =
        settings |> List.exists(setting -> match setting {
            case Setting.Load => true
            case _            => false
        })

    def exporting(settings: List[Setting]): Bool =
        settings |> List.exists(setting -> match setting {
            case Setting.Export => true
            case _              => false
        })

    def serving(settings: List[Setting]): Bool =
        settings |> List.exists(setting -> match setting {
            case Setting.Serve => true
            case _             => false
        })

    /// The last `--database` wins, as a repeated option usually does.
    def databaseUrl(settings: List[Setting]): Option[String] =
        settings |> List.foldLeft((acc, setting) -> match setting {
            case Setting.Database(url) => Some(url)
            case _                     => acc
        }, None)

    def port(settings: List[Setting]): Int32 =
        settings |> List.foldLeft((acc, setting) -> match setting {
            case Setting.Port(number) => number
            case _                    => acc
        }, defaultPort())

    /// Whether this run is the timing-lines report, which is neither a stage of a
    /// converting run nor the server.
    def reporting(settings: List[Setting]): Bool =
        settings |> List.exists(setting -> match setting {
            case Setting.TimingLines => true
            case _                   => false
        })

    /// The round to read, the season to read it against, how far apart one line
    /// may come to stand in the two readings, and the directory the feeds are in.
    def reportCommand(settings: List[Setting], nonOptions: List[String]): Result[ArgsError, Command] =
        forM(
            csv       <- required("csv", csvDir(settings));
            named     <- namedRound(nonOptions);
            against   <- againstSeason(settings);
            tolerance <- distanceAllowed(settings)
        ) yield Command.TimingLines({
            csv = csv,
            season = named#season,
            id = named#id,
            against = against,
            tolerance = tolerance
        })

    /// The round a report was asked for, with its season carried alongside -- the
    /// `Motorsport.Calendar` entry's own season, which is what names the directory
    /// its feed is in.
    type alias Named = {
        season = Int32,
        id = String
    }

    /// One round named outright, and named as one on the calendar: the season
    /// directory a feed is read out of is a season the championship ran, not any
    /// four digits a reader types.
    def namedRound(nonOptions: List[String]): Result[ArgsError, Named] =
        match nonOptions {
            case only :: Nil =>
                match roundName(only) {
                    case Some((season, id)) => Ok({ season = season, id = id })
                    case None               =>
                        Err(ArgsError.ParseErrors("\"${only}\" names no round: name one as <season>/<id>, like 2026/cota_6h." :: Nil))
                }
            case Nil    => Err(ArgsError.ParseErrors("the report reads one round, named as <season>/<id>." :: Nil))
            case extras => Err(ArgsError.UnexpectedArguments(extras))
        }

    /// The last `--against` wins, as the last `--database` does. A season is
    /// read as an integer and not checked against `Motorsport.Calendar`: the
    /// directory that is not there is named by the report itself, which is the
    /// one place that knows whether a season ran this round.
    def againstSeason(settings: List[Setting]): Result[ArgsError, Option[Int32]] =
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
                            Err(ArgsError.ParseErrors("\"${name}\" is not a season: --against names a year, like 2025." :: Nil))
                    case None =>
                        Err(ArgsError.ParseErrors("\"${name}\" is not a season: --against names a year, like 2025." :: Nil))
                }
        }

    /// The distance allowed, defaulting to the report's own and refusing nought:
    /// a run that allows no distance calls every two seasons run on different
    /// lines, which is the one answer nobody came for.
    def distanceAllowed(settings: List[Setting]): Result[ArgsError, Float64] =
        match last(toleranceNamed, settings) {
            case None            => Ok(defaultTolerance())
            case Some(spelled)   =>
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
            "Usage: cli-run --csv <dir> --out <dir>, serve-api, or --timing-lines --csv <dir> <season>/<id>",
            optionDescrs()
        )

}
