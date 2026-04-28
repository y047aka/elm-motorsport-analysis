/// `Motorsport` モジュールの親宣言。実体はサブモジュール
/// (`Motorsport.Car`, `Motorsport.Events`, `Motorsport.Metadata`,
/// `Motorsport.RawLap`) に分かれて `Motorsport/` ディレクトリ配下に
/// 配置される。Rust 側 `cli/motorsport/` クレートと命名を揃えている。
///
/// 親宣言が必要な理由は `Cli.flix` のコメント参照。
pub mod Motorsport { }
