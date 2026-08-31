mod Cli.Args {

    use Util.GetOpt.ArgDescr
    use Util.GetOpt.OptionDescr

    pub enum ArgsError with ToString {
        case MissingRoot
        case UnexpectedArguments(List[String])
        case ParseErrors(List[String])
    }

    /// Where the season directories are, and where the rows go. What to convert
    /// comes from `Motorsport.Calendar`, so there is no per-file input and
    /// nothing to redirect a single file's output to.
    pub type alias ParsedArgs = {
        root = String,
        postgres = Option[String]
    }

    enum Setting { case Postgres(String) }

    def optionDescrs(): List[OptionDescr[Setting]] =
        {
            optionIds     = Nil,
            optionNames   = "postgres" :: Nil,
            argDescriptor = ArgDescr.ReqArg(url -> Some(Setting.Postgres(url)), "URL"),
            explanation   = "JDBC URL to compute the run in\n(defaults to DATABASE_URL)"
        } :: Nil

    pub def parse(args: List[String]): Result[ArgsError, ParsedArgs] =
        forM(
            result <- getOptResult(args);
            root   <- extractRoot(result#nonOptions)
        ) yield { root = root, postgres = postgresUrl(result#options) }

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

    /// The last `--postgres` wins, as a repeated option usually does.
    def postgresUrl(settings: List[Setting]): Option[String] =
        settings |> List.foldLeft((_acc, setting) -> match setting {
            case Setting.Postgres(url) => Some(url)
        }, None)

    pub def usage(): String =
        Util.GetOpt.usageInfo("Usage: cli-run <dir holding the season directories>", optionDescrs())

}
