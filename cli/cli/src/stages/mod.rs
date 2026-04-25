//! Per-stage implementations composed by `crate::process_file`.
//!
//! 6-stage mapping:
//! 1. [`files::read_csv`]           — Stage 1 (read)
//! 2. [`csv_input::parse`]          — Stage 2 (parse: CSV → `CsvRow`)
//! 3. [`structure::structure`]      — Stage 3 (structure: `CsvRow` → `LapRecord`)
//! 4. [`transform::build_outputs`]  — Stage 4 (aggregate/project)
//! 5. [`output::to_json_pretty`]    — Stage 5 (serialize)
//! 6. [`files::write_json`]         — Stage 6 (write)
//!
//! [`output`] owns the JSON shapes (`RawLap` / `MetadataOutput`) and the
//! serialization helper. [`transform`] owns the computation that fills them.

pub(crate) mod csv_input;
pub(crate) mod files;
pub(crate) mod output;
pub(crate) mod structure;
pub(crate) mod transform;
