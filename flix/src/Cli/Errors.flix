pub mod Cli.Errors {

    use Util.Files.FileError

    pub enum CliError with ToString {
        case PathNotFound(String)
        case NoCsvFiles(String)
        case OutputWithDirectory
        case EmptyFile(String)
        case File(FileError)
    }

}
