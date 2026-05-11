mod Util.Files {

    pub enum FileError {
        case ReadError(String, String)   // path, underlying message
        case WriteError(String, String)
        case AccessError(String)         // failure to obtain path stat / existence
        case GlobError(String)
    }

    instance ToString[FileError] {
        pub def toString(e: FileError): String = match e {
            case FileError.ReadError(path, msg)  => "Failed to read ${path} (caused by: ${msg})"
            case FileError.WriteError(path, msg) => "Failed to write ${path} (caused by: ${msg})"
            case FileError.AccessError(msg)      => "File access error (caused by: ${msg})"
            case FileError.GlobError(msg)        => "Directory glob error (caused by: ${msg})"
        }
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
    /// Uses `{*.csv,**/*.csv}` to match both direct children and nested files.
    pub def walkCsvFiles(dirPath: String): Result[FileError, List[String]] \ IO =
        Fs.Glob.runWithIO(() -> Fs.Glob.glob(dirPath, "{*.csv,**/*.csv}"))
            |> Result.mapErr(e -> FileError.GlobError("${e}"))

}
