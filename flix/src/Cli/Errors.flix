mod Cli.Errors {

    use Util.Files.FileError

    pub enum CliError {
        case InputPathNotFound(String)
        case RootNotADirectory(String)
        case EmptyFile(String)
        case File(FileError)
        case Csv({ path = String, message = String })
        case Database(String)
        case RoundNotLoaded
    }

    instance ToString[CliError] {
        pub def toString(e: CliError): String = match e {
            case CliError.InputPathNotFound(p) => "Path not found: ${p}"
            case CliError.RootNotADirectory(p) => "Not a directory: ${p} (expected the directory holding the season directories)"
            case CliError.EmptyFile(p)         => "Empty file: ${p}"
            case CliError.File(cause)          => "${cause}"
            case CliError.Csv(r)               => "Failed to decode ${r#path} (caused by: ${r#message})"
            case CliError.Database(cause)      => "Database error (caused by: ${cause})"
            case CliError.RoundNotLoaded       => "No rows loaded. Convert the round before exporting it."
        }
    }

}
