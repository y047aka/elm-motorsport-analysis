mod Util.Files {

    pub enum FileError with ToString {
        case ReadError(String, String)   // path, underlying message
        case WriteError(String, String)
        case AccessError(String)         // failure to obtain path stat / existence
        case ListDirError(String)
    }

    pub def readLines(path: String): Result[FileError, List[String]] \ IO =
        Fs.FileRead.runWithIO(() ->
            Fs.ReadLines.runWithFileRead(() ->
                Fs.ReadLines.readLines(path)
            )
        ) |> Result.mapErr(e -> FileError.ReadError(path, "${e}"))

    pub def writeFile(path: String, content: String): Result[FileError, Unit] \ IO =
        Fs.FileWrite.runWithIO(() ->
            Fs.WriteFile.runWithFileWrite(() ->
                Fs.WriteFile.write({str = content}, path)
            )
        ) |> Result.mapErr(e -> FileError.WriteError(path, "${e}"))

    pub def exists(path: String): Result[FileError, Bool] \ IO =
        Fs.FileStat.runWithIO(() -> Fs.FileStat.exists(path))
            |> Result.mapErr(e -> FileError.AccessError("${e}"))

    pub def isDirectory(path: String): Result[FileError, Bool] \ IO =
        Fs.FileStat.runWithIO(() -> Fs.FileStat.isDirectory(path))
            |> Result.mapErr(e -> FileError.AccessError("${e}"))

    def listDir(path: String): Result[FileError, List[String]] \ IO =
        Fs.DirList.runWithIO(() -> Fs.DirList.list(path))
            |> Result.mapErr(e -> FileError.ListDirError("${e}"))

    /// Recursively walks the given directory and returns every path ending in `.csv`.
    /// Descends into subdirectories without a depth limit.
    pub def walkCsvFiles(dirPath: String): Result[FileError, List[String]] \ IO =
        forM(
            entries <- listDir(dirPath);
            result  <- gatherCsvs(dirPath, entries)
        ) yield result

    def gatherCsvs(dirPath: String, entries: List[String]): Result[FileError, List[String]] \ IO =
        match entries {
            case Nil => Ok(Nil)
            case e :: rest =>
                let fullPath = "${dirPath}/${e}";
                forM(
                    isDir <- isDirectory(fullPath);
                    head  <- if (isDir) walkCsvFiles(fullPath)
                             else if (String.endsWith({suffix = ".csv"}, fullPath)) Ok(fullPath :: Nil)
                             else Ok(Nil);
                    tail  <- gatherCsvs(dirPath, rest)
                ) yield List.append(head, tail)
        }

}
