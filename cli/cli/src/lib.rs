pub mod args;
pub mod error;
pub mod output;
pub mod pipeline;
pub mod preprocess;

pub use args::parse_args;
pub use error::CliError;
pub use output::{MetadataOutput, create_laps_output, create_metadata_output};
pub use pipeline::FileTask;
pub use preprocess::{LapWithMetadata, group_laps_by_car, parse_laps_from_csv};

use std::path::PathBuf;

use pipeline::ProcessingReport;

pub struct FileOutcome {
    pub input_path: PathBuf,
    pub result: Result<ProcessingReport, CliError>,
}

pub fn run(tasks: Vec<FileTask>) -> impl Iterator<Item = FileOutcome> {
    tasks.into_iter().map(|task| {
        let input_path = task.input_path().to_path_buf();
        let result = pipeline::process_file(&task);
        FileOutcome { input_path, result }
    })
}
