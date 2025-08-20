use std::error::Error;
use std::fs;
use std::path::Path;

pub mod config;
pub mod output;
pub mod preprocess;

pub use config::{Config, InputType};
pub use output::{Output, create_output};
pub use preprocess::{LapWithMetadata, group_laps_by_car, parse_laps_from_csv};

/// Process a single CSV file and convert to JSON
fn process_single_file(config: &Config) -> Result<(), Box<dyn Error>> {
    // Extract input path and other parameters from config
    let (input_path, output_path, event_name) = match &config.input_type {
        InputType::File(file_path) => (
            file_path.as_str(),
            config.output_file.clone(),
            config.event_name.as_deref(),
        ),
        InputType::Directory(_) => {
            unreachable!("Directory config should not reach process_single_file")
        }
    };

    let csv_content = fs::read_to_string(input_path)
        .map_err(|e| format!("Failed to read input file '{}': {}", input_path, e))?;

    let laps_with_metadata = parse_laps_from_csv(&csv_content);
    let cars = group_laps_by_car(laps_with_metadata.clone());
    println!("Read {} cars from CSV '{}'", cars.len(), input_path);

    let event_name = event_name
        .or_else(|| Path::new(input_path).file_stem().and_then(|s| s.to_str()))
        .unwrap_or("test_event");

    let output = create_output(event_name, &laps_with_metadata, &cars);

    let json = serde_json::to_string_pretty(&output)
        .map_err(|e| format!("Failed to serialize output to JSON: {e}"))?;

    let output_path = output_path
        .unwrap_or_else(|| {
            Path::new(input_path)
                .with_extension("json")
                .to_string_lossy()
                .into_owned()
        })
        .to_string();

    fs::write(&output_path, &json)
        .map_err(|e| format!("Failed to write output file '{}': {e}", output_path))?;

    println!("Wrote JSON to {}", output_path);
    Ok(())
}

/// Find all CSV files in a directory recursively
fn find_csv_files(dir_path: &str) -> Result<Vec<String>, Box<dyn Error>> {
    let mut csv_files = Vec::new();
    let entries = fs::read_dir(dir_path)
        .map_err(|e| format!("Failed to read directory '{}': {}", dir_path, e))?;

    for entry in entries {
        let entry = entry.map_err(|e| format!("Failed to read directory entry: {}", e))?;
        let path = entry.path();

        if path.is_dir() {
            // Recursively search subdirectories
            let subdir_path = path.to_string_lossy().to_string();
            let mut subdir_files = find_csv_files(&subdir_path)?;
            csv_files.append(&mut subdir_files);
        } else if let Some(extension) = path.extension() {
            if extension == "csv" {
                csv_files.push(path.to_string_lossy().to_string());
            }
        }
    }

    Ok(csv_files)
}

pub fn run(config: Config) -> Result<(), Box<dyn Error>> {
    match &config.input_type {
        InputType::File(_) => {
            process_single_file(&config)?;
        }
        InputType::Directory(dir_path) => {
            println!("Scanning directory '{}' for CSV files...", dir_path);
            let csv_files = find_csv_files(dir_path)?;

            if csv_files.is_empty() {
                println!("No CSV files found in directory '{}'", dir_path);
                return Ok(());
            }

            println!("Found {} CSV file(s) to process", csv_files.len());

            let mut processed = 0;
            let mut errors = 0;

            for csv_file in &csv_files {
                println!("Processing: {}", csv_file);

                // Create a file-specific config for each CSV file
                let file_config = Config {
                    input_type: InputType::File(csv_file.clone()),
                    output_file: Some(
                        Path::new(csv_file)
                            .with_extension("json")
                            .to_string_lossy()
                            .into_owned(),
                    ),
                    event_name: Path::new(csv_file)
                        .file_stem()
                        .and_then(|s| s.to_str())
                        .map(|s| s.to_string()),
                };

                match process_single_file(&file_config) {
                    Ok(_) => processed += 1,
                    Err(e) => {
                        eprintln!("Error processing '{}': {}", csv_file, e);
                        errors += 1;
                    }
                }
            }

            println!(
                "Batch processing completed: {} processed, {} errors",
                processed, errors
            );
        }
    }

    Ok(())
}
