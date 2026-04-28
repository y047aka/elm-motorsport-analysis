//! Race timing CSV → analysis JSON converter (CLI library).
//!
//! # Public API
//! - `run`: TRPL-style entry that consumes argv and drives the whole program
//! - `RunSummary`: success / error counts; `exit_code()` maps to an OS exit
//! - `FileTask`: one-file unit of work
//! - `parse_args` / `SetupError` / `FileError` / `WithChain`
//!
//! # Per-file pipeline
//!
//! ```text
//! read ─▶ parse ─▶ structure ─▶ transform ─▶ serialize ─▶ write
//! (Stage 1) (2)      (3)          (4)          (5)        (6)
//! ```
//!
//! Each stage lives under [`stages`]. This file owns the `FileTask` orchestration
//! and the six-stage composition in [`process_file`].

pub mod args;
pub mod error;

pub(crate) mod domain;
pub(crate) mod events;
pub(crate) mod stages;

pub use args::parse_args;
pub use error::{FileError, SetupError, WithChain};

use std::path::{Path, PathBuf};
use std::process::ExitCode;

// ================================================================
// Public API types
// ================================================================

pub struct FileTask {
    input_path: PathBuf,
    output_path: PathBuf,
    event_name: String,
}

impl FileTask {
    /// `output_override = None` derives the output path from `input_path` by
    /// swapping the extension to `.json`.
    pub fn new(input_path: PathBuf, output_override: Option<PathBuf>) -> Self {
        let stem = input_path
            .file_stem()
            .unwrap_or_else(|| std::ffi::OsStr::new("output"))
            .to_string_lossy();

        let output_path = output_override.unwrap_or_else(|| input_path.with_extension("json"));
        let event_name = stem.to_string();

        Self {
            input_path,
            output_path,
            event_name,
        }
    }

    pub fn input_path(&self) -> &Path {
        &self.input_path
    }

    pub fn output_path(&self) -> &Path {
        &self.output_path
    }

    pub fn event_name(&self) -> &str {
        &self.event_name
    }

    pub fn laps_path(&self) -> PathBuf {
        let stem = self
            .output_path
            .file_stem()
            .unwrap_or_default()
            .to_string_lossy();
        self.output_path
            .with_file_name(format!("{}_laps.json", stem))
    }
}

#[derive(Debug, Default)]
pub struct RunSummary {
    pub processed: u32,
    pub errors: u32,
}

impl RunSummary {
    /// `FAILURE` if any file failed, `SUCCESS` otherwise.
    pub fn exit_code(&self) -> ExitCode {
        if self.errors == 0 {
            ExitCode::SUCCESS
        } else {
            ExitCode::FAILURE
        }
    }
}

struct ProcessingReport {
    car_count: usize,
    metadata_path: PathBuf,
    laps_path: PathBuf,
}

// ================================================================
// Program entry point
// ================================================================

/// Runs the whole program against `argv`.
///
/// - Argv parsing failures bubble up as `Err` (setup-phase error).
/// - Per-file failures do not bubble up: they are logged via `log::error!` and
///   counted in [`RunSummary::errors`]. Callers convert the summary to an OS
///   exit code via [`RunSummary::exit_code`].
pub fn run(args: impl Iterator<Item = String>) -> Result<RunSummary, SetupError> {
    let tasks = parse_args(args)?;
    let mut summary = RunSummary::default();

    for task in tasks {
        match process_file(&task) {
            Ok(report) => {
                log::info!(
                    "Read {} cars from CSV '{}'",
                    report.car_count,
                    task.input_path().display()
                );
                log::info!("Wrote metadata JSON to {}", report.metadata_path.display());
                log::info!("Wrote laps JSON to {}", report.laps_path.display());
                summary.processed += 1;
            }
            Err(error) => {
                log::error!("{}", WithChain(&error));
                summary.errors += 1;
            }
        }
    }

    log::info!(
        "Processing completed: {} processed, {} errors",
        summary.processed,
        summary.errors
    );
    Ok(summary)
}

// ================================================================
// Per-file execution
// ================================================================

fn process_file(task: &FileTask) -> Result<ProcessingReport, FileError> {
    use stages::{csv_input, files, output, structure, transform};

    // Stage 1: read
    let csv_content = files::read_csv(task.input_path())?;

    // Stage 2: parse — CSV text to `CsvRow` list
    let rows = csv_input::parse(&csv_content);

    // Stage 3: structure — `CsvRow` to `LapRecord`
    let records = structure::structure(rows);

    // Stage 4: transform — `LapRecord` list to serializable shapes
    let (raw_laps, metadata) = transform::build_outputs(records, task.event_name());
    let car_count = metadata.starting_grid.len();

    // Stage 5: serialize
    let metadata_json = output::to_json_pretty(&metadata, "metadata")?;
    let laps_json = output::to_json_pretty(&raw_laps, "laps")?;

    // Stage 6: write
    let metadata_path = task.output_path().to_path_buf();
    let laps_path = task.laps_path();
    files::write_json(&metadata_path, &metadata_json)?;
    files::write_json(&laps_path, &laps_json)?;

    Ok(ProcessingReport {
        car_count,
        metadata_path,
        laps_path,
    })
}

// ================================================================
// Test-only hooks
// ================================================================

/// Intra-crate access for integration tests. Not part of the public API.
#[doc(hidden)]
pub mod for_testing {
    pub use crate::domain::LapRecord;
    pub use crate::stages::output::MetadataOutput;
    pub use crate::stages::transform::build_outputs;

    /// Runs the parse + structure stages in one call.
    pub fn parse_and_structure(csv: &str) -> Vec<LapRecord> {
        crate::stages::structure::structure(crate::stages::csv_input::parse(csv))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn file_task_default_output() {
        let task = FileTask::new(PathBuf::from("input.csv"), None);
        assert_eq!(task.output_path(), Path::new("input.json"));
        assert_eq!(task.event_name(), "input");
    }

    #[test]
    fn file_task_with_output_override() {
        let task = FileTask::new(PathBuf::from("input.csv"), Some(PathBuf::from("custom.json")));
        assert_eq!(task.output_path(), Path::new("custom.json"));
        assert_eq!(task.event_name(), "input");
    }
}
