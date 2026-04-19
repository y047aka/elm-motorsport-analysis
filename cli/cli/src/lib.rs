use std::error::Error;

pub mod config;
pub mod output;
pub mod pipeline;
pub mod preprocess;

pub use config::{Config, InputType};
pub use output::{MetadataOutput, create_laps_output, create_metadata_output};
pub use preprocess::{LapWithMetadata, group_laps_by_car, parse_laps_from_csv};

pub fn run(config: Config) -> Result<(), Box<dyn Error>> {
    let tasks = config.into_tasks()?;

    if tasks.is_empty() {
        println!("No CSV files found to process");
        return Ok(());
    }

    let is_batch = tasks.len() > 1;
    if is_batch {
        println!("Found {} CSV file(s) to process", tasks.len());
    }

    let mut processed = 0;
    let mut errors = 0;

    for task in &tasks {
        if is_batch {
            println!("Processing: {}", task.input_path);
        }
        match pipeline::process_file(task) {
            Ok(_) => processed += 1,
            Err(e) => {
                eprintln!("Error processing '{}': {}", task.input_path, e);
                errors += 1;
            }
        }
    }

    if is_batch {
        println!(
            "Batch processing completed: {} processed, {} errors",
            processed, errors
        );
    }

    Ok(())
}
