pub mod config;
pub mod error;
pub mod output;
pub mod pipeline;
pub mod preprocess;

pub use config::Config;
pub use error::CliError;
pub use output::{MetadataOutput, create_laps_output, create_metadata_output};
pub use preprocess::{LapWithMetadata, group_laps_by_car, parse_laps_from_csv};

use std::path::PathBuf;

use pipeline::ProcessingReport;

pub enum FileResult {
    Processed {
        input_path: PathBuf,
        report: ProcessingReport,
    },
    Failed {
        input_path: PathBuf,
        error: CliError,
    },
}

pub fn run(config: Config) -> impl Iterator<Item = FileResult> {
    config.into_tasks().into_iter().map(|task| {
        let input_path = task.input_path().to_path_buf();
        match pipeline::process_file(&task) {
            Ok(report) => FileResult::Processed {
                input_path,
                report,
            },
            Err(error) => FileResult::Failed { input_path, error },
        }
    })
}
