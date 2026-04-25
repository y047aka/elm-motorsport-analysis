//! パイプライン各ステージの実装。`crate::process_file` から合成される。
//!
//! - [`io`]: Stage 1 & 6（read/write）
//! - [`csv_input`]: Stage 2（parse: CSV → `CsvRow`）
//! - [`structure`]: Stage 3（structure: `CsvRow` → `LapRecord`）
//! - [`transform`]: Stage 4a（aggregate: `LapRecord` → `Car`）
//! - [`output`]: Stage 4b/5（project + serializers）

pub(crate) mod csv_input;
pub(crate) mod io;
pub(crate) mod output;
pub(crate) mod structure;
pub(crate) mod transform;
