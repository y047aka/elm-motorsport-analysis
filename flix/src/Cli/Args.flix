mod Cli.Args {

    use Util.GetOpt.ArgDescr
    use Util.GetOpt.OptionDescr

    pub enum ArgsError with ToString {
        case MissingRoot
        case UnexpectedArguments(List[String])
        case ParseErrors(List[String])
    }

    /// Converting takes the directory holding the season directories, and where
    /// the rows go. What to convert comes from `Motorsport.Calendar`, so there
    /// is no per-file input and nothing to redirect a single file's output to.
    /// Serving reads the rounds a run has already loaded, so it takes a database
    /// and no directory.
    pub enum Command {
        case Convert({ root = String, postgres = Option[String] })
        case Serve({ port = Int32, postgres = Option[String] })
    }

    def defaultPort(): Int32 = 8080

    enum Setting {
        case Postgres(String)
        case Serve
        case Port(Int32)
    }

    def optionDescrs(): List[OptionDescr[Setting]] =
        {
            optionIds     = Nil,
            optionNames   = "postgres" :: Nil,
            argDescriptor = ArgDescr.ReqArg(url -> Some(Setting.Postgres(url)), "URL"),
            explanation   = "JDBC URL to compute the run in\n(defaults to DATABASE_URL)"
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
        } :: Nil

    pub def parse(args: List[String]): Result[ArgsError, Command] =
        forM(
            result  <- getOptResult(args);
            command <- toCommand(result#options, result#nonOptions)
        ) yield command

    def toCommand(settings: List[Setting], nonOptions: List[String]): Result[ArgsError, Command] =
        let postgres = postgresUrl(settings);
        if (serving(settings))
            match nonOptions {
                case Nil    => Ok(Command.Serve({ port = port(settings), postgres = postgres }))
                case extras => Err(ArgsError.UnexpectedArguments(extras))
            }
        else
            extractRoot(nonOptions)
                |> Result.map(root -> Command.Convert({ root = root, postgres = postgres }))

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

    def serving(settings: List[Setting]): Bool =
        settings |> List.exists(setting -> match setting {
            case Setting.Serve => true
            case _             => false
        })

    /// The last `--postgres` wins, as a repeated option usually does.
    def postgresUrl(settings: List[Setting]): Option[String] =
        settings |> List.foldLeft((acc, setting) -> match setting {
            case Setting.Postgres(url) => Some(url)
            case _                     => acc
        }, None)

    def port(settings: List[Setting]): Int32 =
        settings |> List.foldLeft((acc, setting) -> match setting {
            case Setting.Port(number) => number
            case _                    => acc
        }, defaultPort())

    pub def usage(): String =
        Util.GetOpt.usageInfo("Usage: cli-run <dir holding the season directories>", optionDescrs())

}
