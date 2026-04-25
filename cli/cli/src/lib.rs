//! 公式 CLI API:
//! - [`FileTask`] / [`run`] でファイル処理を実行
//! - [`parse_args`] で `Vec<FileTask>` を argv から構築
//! - エラー型は [`CliError`]
//!
//! 内部のパイプラインステージ（`pipeline::csv_input` / `pipeline::structure` /
//! `pipeline::transform` / `pipeline::output` など）はプロダクションコードから
//! 直接呼ぶためのものではなく、integration test 用に [`for_testing`] から
//! アクセスする。

pub mod args;
pub mod error;
pub mod pipeline;

pub(crate) mod domain;

pub use args::parse_args;
pub use error::CliError;
pub use pipeline::{FileOutcome, FileTask, ProcessingReport, run};

/// Integration test 用の内部構造アクセス。プロダクションコードからは使用しない。
///
/// パイプラインの各ステージを個別に呼び出したり、中間表現 [`LapRecord`]
/// を直接観察したりするためのエントリポイント。
pub mod for_testing {
    pub use crate::domain::LapRecord;
    pub use crate::pipeline::output::{MetadataOutput, create_laps_output, create_metadata_output};
    pub use crate::pipeline::transform::group_laps_by_car;

    /// CSV テキストからパース + 構造化の 2 ステージを束ねて [`LapRecord`] を得る。
    pub fn parse_and_structure(csv: &str) -> Vec<LapRecord> {
        crate::pipeline::structure::structure(crate::pipeline::csv_input::parse(csv))
    }
}
