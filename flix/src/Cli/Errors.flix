mod Cli.Errors {

    use Util.Files.FileError

    /// Errors surfaced by the CLI pipeline.
    ///
    /// The `Csv` variant carries the input path alongside the underlying
    /// decoder message so callers can report which file failed without
    /// re-threading the path themselves. The `ToString` instance renders
    /// errors in a Rust-`WithChain`-like form: a one-line summary followed
    /// by an indented `caused by:` line for any nested cause.
    pub enum CliError {
        case PathNotFound(String)
        case NoCsvFiles(String)
        case OutputWithDirectory
        case EmptyFile(String)
        case File(FileError)
        case Csv({ path = String, message = String })
    }

    instance ToString[CliError] {
        pub def toString(e: CliError): String = match e {
            case CliError.PathNotFound(p)     => "Path not found: ${p}"
            case CliError.NoCsvFiles(p)       => "No CSV files found in ${p}"
            case CliError.OutputWithDirectory => "--output cannot be used with a directory input"
            case CliError.EmptyFile(p)        => "Empty file: ${p}"
            case CliError.File(cause)         => "${cause}"
            case CliError.Csv(r)              => "Failed to decode ${r#path}\n  caused by: ${r#message}"
        }
    }

}
