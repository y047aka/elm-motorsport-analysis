mod Cli.Stages {

    use Sys.Console
    use Cli.Errors.CliError
    use Cli.FileTask
    use Cli.Stages.CsvInput
    use Cli.Stages.Output
    use Cli.Stages.State
    use Cli.Stages.Transform
    use Cli.Validation

    type alias ProcessingReport = {
        lapCount   = Int32,
        outputPath = String,
        lapsPath   = String
    }

    type alias RunSummary = {
        processed = Int32,
        errors    = Int32
    }

    pub def runAll(tasks: List[FileTask.FileTask]): Int32 \ {IO, Console} =
        let summary = List.foldLeft(
            (acc, task) -> match processFile(task) {
                case Ok(report) =>
                    Console.println("${task#eventName}: Wrote ${report#lapCount} laps");
                    Console.println("${task#eventName}: Metadata -> ${report#outputPath}");
                    Console.println("${task#eventName}: Laps     -> ${report#lapsPath}");
                    { processed = acc#processed + 1, errors = acc#errors }
                case Err(e) =>
                    Console.eprintln("${task#eventName}: ${e}");
                    { processed = acc#processed, errors = acc#errors + 1 }
            },
            { processed = 0, errors = 0 },
            tasks
        );
        Console.println("Processing completed: ${summary#processed} processed, ${summary#errors} errors");
        if (summary#errors == 0) 0 else 1

    /// Every stage has the uniform shape `State -> Result[CliError, State]`
    /// (or `State -> State` for pure stages), so the pipeline composes
    /// purely with `|>`.
    def processFile(task: FileTask.FileTask): Result[CliError, ProcessingReport] \ {IO, Console} =
        Ok(State.init(task))
            |> Result.flatMap(CsvInput.step)
            |> Result.flatMap(Validation.step)
            |> Result.map(Transform.step)
            |> Result.flatMap(Output.step)
            |> Result.map(toReport)

    def toReport(s: State.State): ProcessingReport = {
        lapCount   = s#rendered#lapCount,
        outputPath = s#task#outputPath,
        lapsPath   = s#task#lapsPath
    }

}
