/// CLI 全体で共有するエラー型。CLI 自体が判定するエラー
/// (`PathNotFound` 等) と、下位レイヤ `Util.Files` が返す
/// `FileError` を 1 バリアント `File` で集約する形で定義する。
///
/// これにより `Util.Files` 側の各エラーケースが追加されても、
/// CLI 側は変換処理を変えずに `CliError.File` で受け取れる。
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
