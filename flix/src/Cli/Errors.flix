mod Cli.Errors {

    use Util.Files.FileError

    pub enum CliError {
        case InputPathNotFound(String)
        case NoCsvFilesFound(String)
        case OutputWithDirectory
        case EmptyFile(String)
        case File(FileError)
        case Csv({ path = String, message = String })
    }

    instance ToString[CliError] {
        pub def toString(e: CliError): String = match e {
            case CliError.InputPathNotFound(p) => "Path not found: ${p}"
            case CliError.NoCsvFilesFound(p)   => "No CSV files found in ${p}"
            case CliError.OutputWithDirectory  => "--output cannot be used with a directory input"
            case CliError.EmptyFile(p)         => "Empty file: ${p}"
            case CliError.File(cause)          => "${cause}"
            case CliError.Csv(r)               => "Failed to decode ${r#path} (caused by: ${r#message})"
        }
    }

}
