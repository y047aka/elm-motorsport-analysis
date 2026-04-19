pub mod config;
pub mod error;
pub mod output;
pub mod pipeline;
pub mod preprocess;

pub use config::Config;
pub use error::CliError;
pub use output::{MetadataOutput, create_laps_output, create_metadata_output};
pub use preprocess::{LapWithMetadata, group_laps_by_car, parse_laps_from_csv};

pub struct RunSummary {
    pub processed: usize,
    pub errors: usize,
}

pub fn run(config: Config) -> Result<RunSummary, CliError> {
    if let Config::BatchDirectory { dir_path } = &config {
        log::info!("Scanning directory '{}' for CSV files...", dir_path.display());
    }
    let tasks = config.into_tasks()?;

    if tasks.is_empty() {
        log::info!("No CSV files found to process");
        return Ok(RunSummary { processed: 0, errors: 0 });
    }

    log::info!("Found {} CSV file(s) to process", tasks.len());

    let mut processed = 0;
    let mut errors = 0;

    for task in &tasks {
        log::info!("Processing: {}", task.input_path.display());
        match pipeline::process_file(task) {
            Ok(report) => {
                log::info!("Read {} cars from CSV '{}'", report.car_count, task.input_path.display());
                log::info!("Wrote metadata JSON to {}", report.metadata_path.display());
                log::info!("Wrote laps JSON to {}", report.laps_path.display());
                processed += 1;
            }
            Err(e) => {
                log::error!("Error processing '{}': {}", task.input_path.display(), e);
                errors += 1;
            }
        }
    }

    log::info!(
        "Processing completed: {} processed, {} errors",
        processed, errors
    );

    Ok(RunSummary { processed, errors })
}
