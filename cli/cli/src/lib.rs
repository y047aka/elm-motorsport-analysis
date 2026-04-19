pub mod config;
pub mod error;
pub mod output;
pub mod pipeline;
pub mod preprocess;

pub use config::{Config, InputType};
pub use error::CliError;
pub use output::{MetadataOutput, create_laps_output, create_metadata_output};
pub use preprocess::{LapWithMetadata, group_laps_by_car, parse_laps_from_csv};

pub struct RunSummary {
    pub processed: usize,
    pub errors: usize,
}

fn process_task(task: &pipeline::FileTask) -> bool {
    match pipeline::process_file(task) {
        Ok(report) => {
            log::info!("Read {} cars from CSV '{}'", report.car_count, task.input_path);
            log::info!("Wrote metadata JSON to {}", report.metadata_path);
            log::info!("Wrote laps JSON to {}", report.laps_path);
            true
        }
        Err(e) => {
            log::error!("Error processing '{}': {}", task.input_path, e);
            false
        }
    }
}

pub fn run(config: Config) -> Result<RunSummary, CliError> {
    if let InputType::Directory(dir) = &config.input_type {
        log::info!("Scanning directory '{}' for CSV files...", dir);
    }
    let tasks = config.into_tasks()?;

    let is_batch = tasks.len() > 1;
    if tasks.is_empty() {
        log::info!("No CSV files found to process");
    } else if is_batch {
        log::info!("Found {} CSV file(s) to process", tasks.len());
    }

    let processed = tasks
        .iter()
        .inspect(|task| {
            if is_batch {
                log::info!("Processing: {}", task.input_path);
            }
        })
        .filter(|task| process_task(task))
        .count();
    let errors = tasks.len() - processed;

    if is_batch {
        log::info!(
            "Batch processing completed: {} processed, {} errors",
            processed, errors
        );
    }

    Ok(RunSummary { processed, errors })
}
