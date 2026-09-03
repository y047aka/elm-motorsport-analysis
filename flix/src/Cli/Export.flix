/// The rounds written out as files, read back out of the rows a run sent.
mod Cli.Export {

    use Sys.Console
    use Cli.Errors.CliError
    use Cli.FileTask
    use Cli.Manifest
    use Cli.Output
    use Round.Laps
    use Round.Render
    use Round.Render.Rendered
    use Round.Summary

    type alias RunSummary = {
        exported = Int32,
        errors   = Int32
    }

    pub def runAll(root: String): Int32 \ {IO, Console, Db} =
        let summary = List.foldLeft(
            (acc, task) -> match exportRound(task) {
                case Ok(rendered) =>
                    Console.println("${FileTask.label(task)}: Wrote ${rendered#lapCount} laps");
                    Console.println("${FileTask.label(task)}: Metadata -> ${task#outputPath}");
                    Console.println("${FileTask.label(task)}: Laps     -> ${task#lapsPath}");
                    { exported = acc#exported + 1 | acc }
                case Err(e) =>
                    Console.eprintln("${FileTask.label(task)}: ${e}");
                    { errors = acc#errors + 1 | acc }
            },
            { exported = 0, errors = 0 },
            FileTask.fromCalendar(root)
        );
        let calendarErrors = writeCalendar(root);
        let errors = summary#errors + calendarErrors;
        Console.println("Export completed: ${summary#exported} exported, ${errors} errors");
        if (errors == 0) 0 else 1

    def exportRound(task: FileTask.FileTask): Result[CliError, Rendered] \ {IO, Db} =
        read(task) |> Result.flatMap(rendered ->
            Output.write(task, rendered) |> Result.map(_ -> rendered)
        )

    /// A round the rows hold none of reads as a race that never ran rather than
    /// as a failure, and written out it would replace the round's files with an
    /// empty one.
    pub def read(task: FileTask.FileTask): Result[CliError, Rendered] \ Db =
        forM(
            metadata <- Summary.read(task#entry) |> Result.mapErr(CliError.Database);
            rawLaps  <- Laps.read(task#entry) |> Result.mapErr(CliError.Database);
            _        <- if (List.isEmpty(rawLaps)) Err(CliError.RoundNotLoaded) else Ok()
        ) yield Render.render(metadata, rawLaps)

    /// Written once for the export, not once per round, and written even by one
    /// that wrote no round: the calendar is not made from the laps.
    def writeCalendar(root: String): Int32 \ {IO, Console} =
        match Manifest.write(root) {
            case Ok(path) =>
                Console.println("Calendar -> ${path}");
                0
            case Err(e) =>
                Console.eprintln("Calendar: ${e}");
                1
        }

}
