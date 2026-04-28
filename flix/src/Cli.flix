/// `Cli` モジュールの親宣言。実際の declarations はサブモジュール
/// (`Cli.Args`, `Cli.Errors`, `Cli.Exit`, `Cli.FileTask`, `Cli.Log`,
/// `Cli.Stages`) に分かれて `Cli/` ディレクトリ配下に配置される。
///
/// このファイルが必要な理由: Flix v0.71.0 では、別ファイルが
/// `pub mod Cli.Args { ... }` のような階層宣言を行う前に親モジュール
/// `Cli` が明示的に存在する必要がある。空の親宣言を 1 つ置けば、
/// 兄弟ファイルからの `use Cli.Args` が解決可能になる
/// (Flix 標準ライブラリの `Fs.flix` / `Net.flix` / `Sys.flix` と同パターン)。
pub mod Cli { }
