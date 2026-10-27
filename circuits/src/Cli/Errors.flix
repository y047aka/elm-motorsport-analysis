/// What the commands say when a file goes wrong: the directory they were pointed
/// at, the file they could not read or write, and what a feed said about itself.
/// The read and the writing here are the reporting; a run that *branches* on a
/// missing file — deciding a circuit was never surveyed, say — asks `Util.Files`'
/// `exists` or `isDirectory` first, because the branch is a verdict and not a
/// sentence, and a read's own failure cannot tell a missing file from one that
/// would not read.
///
/// Two readings of a file fail in these words and neither wraps the other: `Read`
/// carries a path resolved against `GEOMETRY_FROM`, which is what the geometry
/// commands read, and `File` carries `Report.Files`' path, which reads where the
/// reader stands. Wrapping one in the other would print a path twice.
///
/// `flix/src` has a `Cli.Errors` of its own, a separate module of the same name in
/// a separate project, carrying the failures of the commands that compute in a
/// database. Writing one here would need a `Db` source linked in first.
///
/// The two directory cases answer a bad `--csv` in the words the CLI's own `--csv`
/// check answers with.
pub mod Cli.Errors {

    use Report.Files
    use Report.Files.FileError

    pub enum CliError {
        case InputPathNotFound(String)
        case RootNotADirectory(String)
        case File(FileError)
        case Csv({ path = String, message = String })
        case Read({ path = String, message = String })
        case Write({ path = String, message = String })
        case Reading(String)
    }

    instance ToString[CliError] {
        pub def toString(e: CliError): String = match e {
            case CliError.InputPathNotFound(p) => "Path not found: ${p}"
            case CliError.RootNotADirectory(p) => "Not a directory: ${p} (expected the directory holding the season directories)"
            case CliError.File(cause)          => "${cause}"
            case CliError.Csv(r)               => "Failed to decode ${r#path} (caused by: ${r#message})"
            case CliError.Read(r)              => "Failed to read ${r#path} (caused by: ${r#message})"
            case CliError.Write(w)             => "Failed to write ${w#path} (caused by: ${w#message})"
            // What a reading found wrong with the data it was handed: no file's
            // fault and no database's.
            case CliError.Reading(problem)     => problem
        }
    }

    /// The directory holding the season directories, checked once rather than once
    /// per round, so a mistyped one reads as one mistake instead of as every race
    /// being missing.
    pub def checkDirectory(dir: String): Result[CliError, Unit] \ IO =
        forM(
            exists <- Files.exists(dir) |> Result.mapErr(CliError.File);
            _      <- if (exists) Ok(()) else Err(CliError.InputPathNotFound(dir));
            isDir  <- Files.isDirectory(dir) |> Result.mapErr(CliError.File);
            _      <- if (isDir) Ok(()) else Err(CliError.RootNotADirectory(dir))
        ) yield ()

    /// A file read, and a file written: the name the reader gave rides along with
    /// what the filesystem said, once. What a reading found wrong with bytes that
    /// did arrive is `Reading`, not these; and a run that branches on the failure
    /// rather than reporting it — deciding a circuit was never surveyed, say —
    /// asks `Util.Files` directly.
    pub def readFile(path: String): Result[CliError, String] \ IO =
        Util.Files.read(path) |>
            Result.mapErr(problem -> CliError.Read({path = path, message = problem}))

    pub def writeFile(path: String, text: String): Result[CliError, Unit] \ IO =
        Util.Files.write(path, text) |>
            Result.mapErr(problem -> CliError.Write({path = path, message = problem}))

}
