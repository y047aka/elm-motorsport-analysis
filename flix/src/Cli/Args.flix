mod Cli.Args {

    pub enum ArgsError with ToString {
        case MissingRoot
        case UnexpectedArguments(List[String])
        case ParseErrors(List[String])
    }

    /// Where the season directories are, and nothing else. What to convert comes
    /// from `Motorsport.Calendar`, so there is no per-file input and nothing to
    /// redirect a single file's output to.
    pub type alias ParsedArgs = {
        root = String
    }

    def optionDescrs(): List[Util.GetOpt.OptionDescr[Unit]] = Nil

    pub def parse(args: List[String]): Result[ArgsError, ParsedArgs] =
        forM(
            result <- getOptResult(args);
            root   <- extractRoot(result#nonOptions)
        ) yield { root = root }

    def getOptResult(args: List[String]): Result[ArgsError, {options = List[Unit], nonOptions = List[String]}] =
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

    pub def usage(): String =
        Util.GetOpt.usageInfo("Usage: cli-run <dir holding the season directories>", optionDescrs())

}
