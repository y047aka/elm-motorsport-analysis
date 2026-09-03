/// The rounds written out as files, read back out of the rows a run sent.
mod Cli.Export {

    use Sys.Console
    use Util.Files
    use Util.Json.Encode.Extra
    use Cli.Errors.CliError
    use Cli.FileTask
    use Motorsport.Calendar
    use Round.Laps
    use Round.Render
    use Round.Summary

    type alias RunSummary = {
        exported = Int32,
        errors   = Int32
    }

    /// The three files' worth of a round, held together so the count reported
    /// is the count of what was written. Nothing outside the export wants all
    /// three at once: an answer carrying the summary has no use for the laps.
    pub type alias Rendered = {
        lapCount     = Int32,
        metadataJson = String,
        lapsJsonl    = String
    }

    /// Where the app reads the exported files from, as `/api/wec` is where it
    /// reads the served rounds from.
    ///
    /// Not where the files are written to. That is the run's argument, and
    /// `../app/static/wec` and `/static/wec` are the same place reached two
    /// different ways.
    pub def urlRoot(): String = "/static/wec"

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
            writeRound(task, rendered) |> Result.map(_ -> rendered)
        )

    /// A round the rows hold none of reads as a race that never ran rather than
    /// as a failure, and written out it would replace the round's files with an
    /// empty one.
    ///
    /// `pub` reaches no further than `Cli.TestExport`, which drives it without
    /// a directory to write into.
    pub def read(task: FileTask.FileTask): Result[CliError, Rendered] \ Db =
        forM(
            metadata <- Summary.read(task#entry) |> Result.mapErr(CliError.Database);
            rawLaps  <- Laps.read(task#entry) |> Result.mapErr(CliError.Database);
            _        <- if (List.isEmpty(rawLaps)) Err(CliError.RoundNotLoaded) else Ok()
        ) yield render(metadata, rawLaps)

    def render(metadata: Motorsport.Metadata.Metadata, rawLaps: List[Motorsport.Wec.RawLap]): Rendered =
        {
            lapCount     = List.length(rawLaps),
            metadataJson = Render.renderMetadata(metadata),
            lapsJsonl    = Render.renderJsonl(rawLaps)
        }

    def writeRound(task: FileTask.FileTask, rendered: Rendered): Result[CliError, Unit] \ IO =
        forM(
            _ <- Files.write(task#outputPath, rendered#metadataJson) |> Result.mapErr(CliError.File);
            _ <- Files.write(task#lapsPath, rendered#lapsJsonl) |> Result.mapErr(CliError.File)
        ) yield ()

    /// Written once for the export, not once per round, and written even by one
    /// that wrote no round: the calendar is not made from the laps. It sits
    /// beside the season directories rather than inside one, because it spans
    /// all of them.
    def writeCalendar(root: String): Int32 \ {IO, Console} =
        let path = "${root}/index.json";
        match Files.write(path, Extra.render(Manifest.toJson(urlRoot(), Calendar.seasons()))) {
            case Ok(_) =>
                Console.println("Calendar -> ${path}");
                0
            case Err(e) =>
                Console.eprintln("Calendar: ${e}");
                1
        }

}
