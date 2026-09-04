mod Cli.Args {

    use Util.GetOpt.ArgDescr
    use Util.GetOpt.OptionDescr
    use Cli.FileTask.Rounds
    use Motorsport.Calendar

    pub enum ArgsError with ToString {
        case MissingRoot
        case UnexpectedArguments(List[String])
        case ParseErrors(List[String])
    }

    /// Converting is the two stages one after the other: the CSV goes into the
    /// rows, and the files are written out of them. `Load` and `Export` are the
    /// same two taken singly. All three take the directory holding the season
    /// directories, and what to convert comes from `Motorsport.Calendar`, so
    /// there is no per-file input and nothing to redirect a single file's
    /// output to. Serving reads the rounds a run has already loaded, so it
    /// takes a database and no directory.
    ///
    /// `exported` narrows the writing stage alone: a round left out of it is
    /// loaded like any other, and `/api` answers for it.
    pub enum Command {
        case Convert({ root = String, database = Option[String], exported = Rounds })
        case Load({ root = String, database = Option[String] })
        case Export({ root = String, database = Option[String], exported = Rounds })
        case Serve({ port = Int32, database = Option[String] })
    }

    def defaultPort(): Int32 = 8080

    /// Where a run that names none computes: a file under the working copy, so
    /// that the rows a run left there are still there to be queried.
    pub def defaultDatabase(): String = "jdbc:sqlite:.db/motorsport.sqlite"

    enum Setting {
        case Database(String)
        case Load
        case Export
        case Serve
        case Port(Int32)
        case ExportOnly(String)
    }

    def optionDescrs(): List[OptionDescr[Setting]] =
        {
            optionIds     = Nil,
            optionNames   = "database" :: Nil,
            argDescriptor = ArgDescr.ReqArg(url -> Some(Setting.Database(url)), "URL"),
            explanation   = "JDBC URL to compute the run in\n(defaults to DATABASE_URL, then ${defaultDatabase()})"
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
        else
            forM(
                root     <- extractRoot(nonOptions);
                exported <- exportedRounds(settings)
            ) yield
                // Naming both stages is naming the run they make up.
                match (loading(settings), exporting(settings)) {
                    case (true, false) => Command.Load({ root = root, database = database })
                    case (false, true) => Command.Export({ root = root, database = database, exported = exported })
                    case _             => Command.Convert({ root = root, database = database, exported = exported })
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

    def extractRoot(nonOptions: List[String]): Result[ArgsError, String] =
        match nonOptions {
            case root :: Nil => Ok(root)
            case Nil         => Err(ArgsError.MissingRoot)
            case extras      => Err(ArgsError.UnexpectedArguments(extras))
        }

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

    pub def usage(): String =
        Util.GetOpt.usageInfo("Usage: cli-run <dir holding the season directories>, or cli-serve", optionDescrs())

}
