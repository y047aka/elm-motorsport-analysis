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
        match GetOpt.getOpt(GetOpt.ArgOrder.Permute, optionDescrs(), args) {
            case Validation.Failure(errors) =>
                Err(ArgsError.ParseErrors(Nec.toList(errors)))
            case Validation.Success(result) =>
                let outputs = List.filterMap(opt -> match opt {
                    case CliOption.Output(p) => Some(p)
                }, result#options);
                let outputFile = match outputs {
                    case Nil      => Ok(None)
                    case p :: Nil => Ok(Some(p))
                    case _        => Err(ArgsError.DuplicateOutput)
                };
                Result.flatMap(out ->
                    match result#nonOptions {
                        case input :: Nil => Ok({ inputPath = input, outputFile = out })
                        case Nil          => Err(ArgsError.MissingInputPath)
                        case extras       => Err(ArgsError.UnexpectedArguments(extras))
                    },
                    outputFile
                )
        }

    pub def usageInfo(): String =
        GetOpt.usageInfo("Usage: flix-run <input.csv|dir>", optionDescrs())

}
