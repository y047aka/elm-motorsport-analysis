use std::error::Error;
use std::fs;
use std::io::Write;

pub mod preprocess;
pub mod output;
pub mod config;

pub use preprocess::{parse_laps_from_csv, group_laps_by_car, LapWithMetadata};
pub use output::{ElmCompatibleOutput, create_elm_compatible_output};
pub use config::Config;



/// メイン実行関数
pub fn run(config: config::Config) -> Result<(), Box<dyn Error>> {
    let csv_content = fs::read_to_string(&config.input_file)?;

    let laps_with_metadata = parse_laps_from_csv(&csv_content);
    let cars = group_laps_by_car(laps_with_metadata.clone());
    println!("Read {} cars from CSV", cars.len());

    // Elm互換形式で出力
    let event_name = config.event_name.as_deref().unwrap_or("test_event");
    let elm_output = output::create_elm_compatible_output(event_name, &laps_with_metadata, &cars);
    let json = serde_json::to_string_pretty(&elm_output)?;

    let output_path = config.output_file.as_deref().unwrap_or("test.json");
    fs::File::create(output_path)
        .unwrap()
        .write_all(json.as_bytes())?;

    println!("Wrote Elm-compatible JSON to {}", output_path);
    Ok(())
}

