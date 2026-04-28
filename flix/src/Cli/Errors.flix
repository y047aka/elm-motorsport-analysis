/// CLI 全体で共有するエラー型と変換ヘルパー。
///
/// `Util.Files.FileError` のような下位レイヤのエラーを、CLI 側のレポート用
/// 型 `CliError` に集約する役目もこのモジュールが担う (依存方向:
/// Cli → Util の片方向のみ)。
pub mod Cli.Errors {

    use Util.Files.FileError

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

    /// `Util.Files.FileError` を `CliError` に変換する。
    pub def fromFileError(e: FileError): CliError =
        match e {
            case FileError.ReadError(p, m)   => CliError.ReadFile(p, m)
            case FileError.WriteError(p, m)  => CliError.WriteFile(p, m)
            case FileError.AccessError(m)    => CliError.PathAccessError(m)
            case FileError.ListDirError(m)   => CliError.ListDirError(m)
        }

    /// `Result[FileError, t]` を `Result[CliError, t]` に持ち上げる薄いラッパ。
    /// `Cli.FileTask` / `Cli.Main` の forM 内で `Files.X` 呼び出しの直後に挟む。
    pub def liftFile(r: Result[FileError, t]): Result[CliError, t] =
        Result.mapErr(fromFileError, r)

}
