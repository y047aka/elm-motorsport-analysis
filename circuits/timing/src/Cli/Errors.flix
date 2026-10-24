/// What a report run says when it has no answer: the directory it was pointed at,
/// the feed it could not read, and what the feed said about itself.
///
/// `flix/src` has a `Cli.Errors` of its own, a separate module of the same name in
/// a separate project, carrying the failures of the commands that compute in a
/// database. Writing one here would need a `Db` source linked in first.
///
/// The two directory cases answer a bad `--csv` in the words the CLI's own `--csv`
/// check answers with.
pub mod Cli.Errors {

    use Util.Files
    use Util.Files.FileError

    pub enum CliError {
        case InputPathNotFound(String)
        case RootNotADirectory(String)
        case File(FileError)
        case Csv({ path = String, message = String })
        case Reading(String)
    }

    instance ToString[CliError] {
        pub def toString(e: CliError): String = match e {
            case CliError.InputPathNotFound(p) => "Path not found: ${p}"
            case CliError.RootNotADirectory(p) => "Not a directory: ${p} (expected the directory holding the season directories)"
            case CliError.File(cause)          => "${cause}"
            case CliError.Csv(r)               => "Failed to decode ${r#path} (caused by: ${r#message})"
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

}
