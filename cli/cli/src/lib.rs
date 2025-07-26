use std::error::Error;
use std::fs;

pub mod preprocess;
pub mod output;
pub mod config;

pub use preprocess::{parse_laps_from_csv, group_laps_by_car, LapWithMetadata};
pub use output::{Output, create_output};
pub use config::Config;


pub fn run(config: Config) -> Result<(), Box<dyn Error>> {
    let csv_content = fs::read_to_string(&config.input_file)
        .map_err(|e| format!("Failed to read input file '{}': {}", config.input_file, e))?;

    let laps_with_metadata = parse_laps_from_csv(&csv_content);
    let cars = group_laps_by_car(laps_with_metadata.clone());
    println!("Read {} cars from CSV", cars.len());

    let event_name = config.event_name.as_deref().unwrap_or("test_event");
    let output = create_output(event_name, &laps_with_metadata, &cars);
    
    let json = serde_json::to_string_pretty(&output)
        .map_err(|e| format!("Failed to serialize output to JSON: {}", e))?;

    let output_path = config.output_file.as_deref().unwrap_or("test.json");
    fs::write(output_path, &json)
        .map_err(|e| format!("Failed to write output file '{}': {}", output_path, e))?;

    println!("Wrote JSON to {}", output_path);
    Ok(())
}
