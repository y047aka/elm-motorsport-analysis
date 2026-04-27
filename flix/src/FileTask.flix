mod FileTask {

    use Cli.CliError

    pub type alias FileTask = {
        inputPath = String,
        outputPath = String,
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

    def eventName(inputPath: String): String =
        let parts = String.split({regex = "/"}, inputPath);
        let fileName = parts |> List.last |> Option.getWithDefault(inputPath);
        let segments = String.split({regex = "\\."}, fileName);
        match segments {
            case _ :: _ :: _ => segments |> List.reverse |> List.drop(1) |> List.reverse |> List.join(".")
            case _           => fileName
        }

}
