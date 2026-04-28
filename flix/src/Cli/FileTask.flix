mod Cli.FileTask {

    use Cli.Args
    use Cli.Errors.CliError
    use Util.Files

    pub type alias FileTask = {
        inputPath = String,
        outputPath = String,
        lapsPath = String,
        eventName = String
    }

    pub def make(inputPath: String, outputOverride: Option[String]): FileTask =
        let outputPath = match outputOverride {
            case Some(p) => p
            case None    => defaultOutputPath(inputPath)
        };
        {
            inputPath   = inputPath,
            outputPath  = outputPath,
            lapsPath    = derivedLapsPath(outputPath),
            eventName   = eventName(inputPath)
        }

    pub def resolve(parsed: Args.ParsedArgs): Result[CliError, List[FileTask]] \ IO =
        let path = parsed#inputPath;
        let outputOverride = parsed#outputFile;
        forM(
            exists <- Files.exists(path);
            _      <- if (exists) Ok(()) else Err(CliError.PathNotFound(path));
            isDir  <- Files.isDirectory(path);
            tasks  <- if (isDir) resolveDir(path, outputOverride)
                      else Ok(make(path, outputOverride) :: Nil)
        ) yield tasks

    def resolveDir(dirPath: String, outputOverride: Option[String]): Result[CliError, List[FileTask]] \ IO =
        match outputOverride {
            case Some(_) => Err(CliError.OutputWithDirectory)
            case None    =>
                forM(
                    csvPaths <- Files.walkCsvFiles(dirPath);
                    csvFiles <- Ok(csvPaths |> List.map(p -> make(p, None)));
                    result   <- if (List.isEmpty(csvFiles))
                                    Err(CliError.NoCsvFiles(dirPath))
                                else
                                    Ok(csvFiles)
                ) yield result
        }

    def defaultOutputPath(inputPath: String): String =
        if (String.endsWith({suffix = ".csv"}, inputPath))
            String.dropRight(4, inputPath) + ".json"
        else
            inputPath + ".json"

    /// `output.json` -> `output_laps.json`、`x.bin` -> `x_laps.json`、
    /// 拡張子なし `x` -> `x_laps.json`。Rust 版 `cli::FileTask::laps_path`
    /// (cli/src/lib.rs L73-81) と同じく拡張子に関わらず `_laps.json` を付与。
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
        let segments = String.split({regex = "\\."}, fileName);
        match segments {
            case _ :: _ :: _ => segments |> List.reverse |> List.drop(1) |> List.reverse |> List.join(".")
            case _           => fileName
        }

}
