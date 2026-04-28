mod Cli.Args {

    pub enum ArgsError with ToString {
        case MissingInputPath
        case MissingOutputValue
        case DuplicateOutput
        case UnexpectedArgument(String)
    }

    pub type alias ParsedArgs = {
        inputPath = String,
        outputFile = Option[String]
    }

    enum ParseState {
        case Ready(Option[String], Option[String])
        case ExpectingOutputValue(Option[String])
    }

    pub def parse(args: List[String]): Result[ArgsError, ParsedArgs] =
        let finalState = List.foldLeft((acc, arg) ->
            Result.flatMap(st -> step(st, arg), acc),
            Ok(ParseState.Ready(None, None)),
            args
        );
        finalState |> Result.flatMap(resolve)

    def step(state: ParseState, arg: String): Result[ArgsError, ParseState] =
        match state {
            case ParseState.ExpectingOutputValue(input) =>
                Ok(ParseState.Ready(input, Some(arg)))
            case ParseState.Ready(input, None) if arg == "--output" =>
                Ok(ParseState.ExpectingOutputValue(input))
            case ParseState.Ready(_, Some(_)) if arg == "--output" =>
                Err(ArgsError.DuplicateOutput)
            case ParseState.Ready(None, output) =>
                Ok(ParseState.Ready(Some(arg), output))
            case ParseState.Ready(Some(_), _) =>
                Err(ArgsError.UnexpectedArgument(arg))
        }

    def resolve(state: ParseState): Result[ArgsError, ParsedArgs] =
        match state {
            case ParseState.Ready(Some(input), output) =>
                Ok({ inputPath = input, outputFile = output })
            case ParseState.Ready(None, _) =>
                Err(ArgsError.MissingInputPath)
            case ParseState.ExpectingOutputValue(_) =>
                Err(ArgsError.MissingOutputValue)
        }

}
