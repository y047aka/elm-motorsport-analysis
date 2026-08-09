mod Cli.FileTask {

    use Cli.Args
    use Cli.Errors.CliError
    use Util.Files

    pub type alias FileTask = {
        inputPath = String,
        outputPath = String,
        lapsPath = String,
        eventName = String,
        season = Option[Int32]
    }

    pub def make(inputPath: String, outputOverride: Option[String]): FileTask =
        let outputPath = outputOverride |> Option.getWithDefault(defaultOutputPath(inputPath));
        {
            inputPath   = inputPath,
            outputPath  = outputPath,
            lapsPath    = derivedLapsPath(outputPath),
            eventName   = eventName(inputPath),
            season      = season(inputPath)
        }

    pub def fromArgs(parsed: Args.ParsedArgs): Result[CliError, List[FileTask]] \ IO =
        let path = parsed#inputPath;
        let outputOverride = parsed#outputFile;
        forM(
            exists <- Files.exists(path) |> Result.mapErr(CliError.File);
            _      <- if (exists) Ok(()) else Err(CliError.InputPathNotFound(path));
            isDir  <- Files.isDirectory(path) |> Result.mapErr(CliError.File);
            tasks  <- if (isDir) resolveDir(path, outputOverride)
                      else Ok(make(path, outputOverride) :: Nil)
        ) yield tasks

    def resolveDir(dirPath: String, outputOverride: Option[String]): Result[CliError, List[FileTask]] \ IO =
        match outputOverride {
            case Some(_) => Err(CliError.OutputWithDirectory)
            case None    =>
                forM(
                    csvPaths <- Files.walkCsvFiles(dirPath) |> Result.mapErr(CliError.File);
                    csvFiles <- Ok(csvPaths |> List.map(p -> make(p, None)));
                    result   <- if (List.isEmpty(csvFiles))
                                    Err(CliError.NoCsvFilesFound(dirPath))
                                else
                                    Ok(csvFiles)
                ) yield result
        }

    def defaultOutputPath(inputPath: String): String =
        if (String.endsWith({suffix = ".csv"}, inputPath))
            String.dropRight(4, inputPath) + ".json"
        else
            inputPath + ".json"

    def derivedLapsPath(outputPath: String): String =
        let pathParts = String.split({regex = "/"}, outputPath);
        let baseName = pathParts |> List.last |> Option.getWithDefault(outputPath);
        let dirPart = match pathParts {
            case _ :: _ :: _ =>
                let dirs = pathParts |> List.reverse |> List.drop(1) |> List.reverse;
                List.join("/", dirs) + "/"
            case _ => ""
        };
        let stem = stripLastExtension(baseName);
        "${dirPart}${stem}_laps.json"

    def stripLastExtension(name: String): String =
        let segments = String.split({regex = "\\."}, name);
        match segments {
            case _ :: _ :: _ => segments |> List.reverse |> List.drop(1) |> List.reverse |> List.join(".")
            case _           => name
        }

    def eventName(inputPath: String): String =
        let parts = String.split({regex = "/"}, inputPath);
        let fileName = parts |> List.last |> Option.getWithDefault(inputPath);
        stripLastExtension(fileName)

    /// The season is the directory the CSV is filed under -- `wec/2025/fuji_6h.csv`
    /// -- which is the only place it is written down: no column of the timing
    /// feed carries the year, and the event name does not either.
    ///
    /// A CSV filed anywhere else, or handed over with no directory above it at
    /// all, has no season to read. Nothing is guessed from the dates inside:
    /// a season and the calendar year it runs in are not the same thing, and
    /// the point of reading the directory is that somebody filed it there.
    def season(inputPath: String): Option[Int32] =
        String.split({regex = "/"}, inputPath)
            |> List.reverse
            |> List.drop(1)
            |> List.head
            |> Option.flatMap(Int32.fromString)

}
