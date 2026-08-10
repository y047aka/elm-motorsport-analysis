///
/// The filesystem as an algebraic effect.
///
/// Subcommands ask for `FileIO` instead of `IO`, so their signatures say
/// "reads files" rather than "does anything". `main` installs the one
/// real handler (`runWithIO`); tests can install an in-memory handler and
/// exercise a whole subcommand without a filesystem.
///
/// The effect offers no way to write: every subcommand audits and reports,
/// so deps-audit cannot alter what it is reading.
///
/// Error messages match the Rust implementation's "<path>: <error>" style.
///
mod DepsAudit.Io {

    ///
    /// A file operation a subcommand may perform. Operation names and
    /// argument order follow the stdlib `Fs` effects (`Fs.ReadFile.read`,
    /// `Fs.FileTest.exists`, `Fs.DirList.list`).
    /// Fallible operations return `Result` rather than aborting, because
    /// every audit decides per call site whether a missing file is fatal
    /// or just a fallback.
    ///
    pub eff FileIO {

        /// Read a whole file as a string.
        def read(f: String): Result[String, String]

        /// Check whether a file or directory exists.
        def exists(f: String): Bool

        /// List the entry names of a directory.
        def list(f: String): Result[String, List[String]]

    }

    /// Handle `FileIO` with the real filesystem (via the stdlib Fs effects).
    pub def runWithIO(f: Unit -> a \ ef): a \ (ef - FileIO) + IO =
        run { f() } with handler FileIO {
            def read(path, k)   = k(readFileIO(path))
            def exists(path, k) = k(existsIO(path))
            def list(path, k)   = k(listDirIO(path))
        }

    def readFileIO(path: String): Result[String, String] \ IO =
        Fs.FileRead.runWithIO(() ->
            Fs.ReadFile.runWithFileRead(() -> Fs.ReadFile.read(path))
        ) |> Result.mapErr(e -> "${path}: ${e}")

    def existsIO(path: String): Bool \ IO =
        Fs.FileStat.runWithIO(() -> Fs.FileStat.exists(path))
            |> Result.getWithDefault(false)

    def listDirIO(path: String): Result[String, List[String]] \ IO =
        Fs.FileSystem.runWithIO(() ->
            Fs.DirList.runWithFileSystem(() -> Fs.DirList.list(path))
        ) |> Result.mapErr(e -> "${path}: ${e}")

}
