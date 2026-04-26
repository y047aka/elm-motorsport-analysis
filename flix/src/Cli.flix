mod Cli {

    pub enum CliError with ToString {
        case PathNotFound(String)
        case PathAccessError(String)
        case ListDirError(String)
        case NoCsvFiles(String)
        case OutputWithDirectory
        case ReadFile(String, String)
        case EmptyFile(String)
        case WriteFile(String, String)
    }

}
