//! パイプライン各ステージの実装。`crate::process_file` から合成される。
//!
//! 6 ステージの対応:
//! 1. [`files::read_csv`]                    — Stage 1 (read)
//! 2. [`csv_input::parse`]                   — Stage 2 (parse: CSV → `CsvRow`)
//! 3. [`structure::structure`]               — Stage 3 (structure: `CsvRow` → `LapRecord`)
//! 4. [`transform::build_outputs`]           — Stage 4 (aggregate/project)
//! 5. [`output::to_json_pretty`]             — Stage 5 (serialize)
//! 6. [`files::write_json`]                  — Stage 6 (write)
//!
//! [`output`] モジュールは JSON の shape（`RawLap` / `MetadataOutput`）と
//! シリアライズヘルパを所有する。中身の計算は [`transform`] が担う。

pub(crate) mod csv_input;
pub(crate) mod files;
pub(crate) mod output;
pub(crate) mod structure;
pub(crate) mod transform;
