/// Reading a file, and nothing else. The writing, the directory-making and the
/// globbing the load and the export do are `flix/src`'s `Util.Files`, and this
/// project's own `Util.Files` resolves every path from `GEOMETRY_FROM` — the
/// report reads where the reader stands, from the feeds' directory alone.
pub mod Report.Files {

    pub enum FileError {
        case ReadError(String, String)   // path, underlying message
        case AccessError(String)         // failure to obtain path stat / existence
    }

    instance ToString[FileError] {
        pub def toString(e: FileError): String = match e {
            case FileError.ReadError(path, msg) => "Failed to read ${path} (caused by: ${msg})"
            case FileError.AccessError(msg)     => "File access error (caused by: ${msg})"
        }
    }

    pub def readLines(path: String): Result[FileError, List[String]] \ IO =
        Fs.FileRead.runWithIO(() ->
            Fs.ReadLines.runWithFileRead(() ->
                Fs.ReadLines.readLines(path)
            )
        ) |> Result.mapErr(e -> FileError.ReadError(path, "${e}"))

    pub def exists(path: String): Result[FileError, Bool] \ IO =
        Fs.FileStat.runWithIO(() -> Fs.FileStat.exists(path))
            |> Result.mapErr(e -> FileError.AccessError("${e}"))

    pub def isDirectory(path: String): Result[FileError, Bool] \ IO =
        Fs.FileStat.runWithIO(() -> Fs.FileStat.isDirectory(path))
            |> Result.mapErr(e -> FileError.AccessError("${e}"))

}
