///
/// Thin wrappers over the Fs effects, with error messages matching the
/// Rust implementation's "<path>: <error>" style.
///
mod DepsAudit.Io {

    /// Read a whole file as a string.
    pub def readFile(path: String): Result[String, String] \ IO =
        Fs.FileRead.runWithIO(() ->
            Fs.ReadFile.runWithFileRead(() -> Fs.ReadFile.read(path))
        ) |> Result.mapErr(e -> "${path}: ${e}")

    /// Write a whole file.
    pub def writeFile(path: String, content: String): Result[String, Unit] \ IO =
        Fs.FileWrite.runWithIO(() ->
            Fs.WriteFile.runWithFileWrite(() -> Fs.WriteFile.write({str = content}, path))
        ) |> Result.mapErr(e -> "${path}: ${e}")

    /// Check whether a file or directory exists.
    pub def exists(path: String): Bool \ IO =
        Fs.FileStat.runWithIO(() -> Fs.FileStat.exists(path))
            |> Result.getWithDefault(false)

    /// List the entry names of a directory.
    pub def listDir(path: String): Result[String, List[String]] \ IO =
        Fs.FileSystem.runWithIO(() ->
            Fs.DirList.runWithFileSystem(() -> Fs.DirList.list(path))
        ) |> Result.mapErr(e -> "${path}: ${e}")

}
