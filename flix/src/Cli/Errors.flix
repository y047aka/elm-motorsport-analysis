/// CLI 全体で共有するエラー型。各サブモジュール (`Cli.FileTask`,
/// `Util.Files` 等) はここで定義された `CliError` を `Result` の Err 側に詰める。
mod Cli.Errors {

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
