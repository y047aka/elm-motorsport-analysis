mod Cli.Args {

    pub enum ArgsError with ToString {
        case MissingInputPath
        case UnexpectedArguments(List[String])
        case DuplicateOutput
        case ParseErrors(List[String])
    }

    pub type alias ParsedArgs = {
        inputPath = String,
        outputFile = Option[String]
    }

    enum CliOption {
        case Output(String)
    }

    def optionDescrs(): List[GetOpt.OptionDescr[CliOption]] =
        {
            optionIds     = Nil,
            optionNames   = "output" :: Nil,
            argDescriptor = GetOpt.ArgDescr.ReqArg(s -> Some(CliOption.Output(s)), "<file>"),
            explanation   = "write metadata JSON to <file>"
        } :: Nil

    pub def parse(args: List[String]): Result[ArgsError, ParsedArgs] =
        forM(
            result <- getOptResult(args);
            out    <- extractOutput(result#options);
            input  <- extractInput(result#nonOptions)
        ) yield { inputPath = input, outputFile = out }

    def getOptResult(args: List[String]): Result[ArgsError, {options = List[CliOption], nonOptions = List[String]}] =
        match GetOpt.getOpt(GetOpt.ArgOrder.Permute, optionDescrs(), args) {
            case Validation.Failure(errors) => Err(ArgsError.ParseErrors(Nec.toList(errors)))
            case Validation.Success(result) => Ok(result)
        }

    def extractOutput(opts: List[CliOption]): Result[ArgsError, Option[String]] =
        match opts {
            case Nil                        => Ok(None)
            case CliOption.Output(p) :: Nil => Ok(Some(p))
            case _                          => Err(ArgsError.DuplicateOutput)
        }

    def extractInput(nonOptions: List[String]): Result[ArgsError, String] =
        match nonOptions {
            case input :: Nil => Ok(input)
            case Nil          => Err(ArgsError.MissingInputPath)
            case extras       => Err(ArgsError.UnexpectedArguments(extras))
        }

    pub def usageInfo(): String =
        GetOpt.usageInfo("Usage: flix-run <input.csv|dir>", optionDescrs())

}
