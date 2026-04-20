mod FileTask {

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

    pub def resolve(parsed: Args.ParsedArgs): Result[String, List[FileTask]] \ IO =
        let path = parsed#inputPath;
        let outputOverride = parsed#outputFile;
        forM(
            exists <- Fs.FileStat.runWithIO(() -> Fs.FileStat.exists(path))
                        |> Result.mapErr(e -> "Cannot access path: ${e}");
            _      <- if (exists) Ok(()) else Err("Input path not found: ${path}");
            isDir  <- Fs.FileStat.runWithIO(() -> Fs.FileStat.isDirectory(path))
                        |> Result.mapErr(e -> "Cannot check path type: ${e}");
            tasks  <- if (isDir) resolveDir(path, outputOverride)
                      else Ok(make(path, outputOverride) :: Nil)
        ) yield tasks

    def resolveDir(dirPath: String, outputOverride: Option[String]): Result[String, List[FileTask]] \ IO =
        match outputOverride {
            case Some(_) => Err("--output cannot be used with a directory input")
            case None    =>
                let listResult = Fs.DirList.runWithIO(() -> Fs.DirList.list(dirPath));
                match listResult {
                    case Err(e) => Err("Cannot list directory: ${e}")
                    case Ok(entries) =>
                        let csvFiles = entries
                            |> List.filter(e -> String.endsWith({suffix = ".csv"}, e))
                            |> List.map(e -> make("${dirPath}/${e}", None));
                        if (List.isEmpty(csvFiles))
                            Err("No CSV files found in: ${dirPath}")
                        else
                            Ok(csvFiles)
                }
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
