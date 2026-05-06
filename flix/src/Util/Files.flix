mod Util.Files {

    pub enum FileError with ToString {
        case ReadError(String, String)   // path, underlying message
        case WriteError(String, String)
        case AccessError(String)         // failure to obtain path stat / existence
        case GlobError(String)
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

    /// Recursively finds every `.csv` file under `dirPath`.
    pub def walkCsvFiles(dirPath: String): Result[FileError, List[String]] \ IO =
        Fs.Glob.runWithIO(() -> Fs.Glob.glob(dirPath, "**/*.csv"))
            |> Result.mapErr(e -> FileError.GlobError("${e}"))

}
