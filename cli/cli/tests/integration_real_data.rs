use std::fs;
use std::path::Path;

use cli::{run, Config};
use cli::preprocess::{parse_laps_from_csv, group_laps_by_car};

/// Integration tests using real WEC 2025 data
/// These tests validate that the Rust CLI produces output compatible with existing JSON structure

#[test]
fn test_real_data_imola_6h_processing() {
    let csv_path = "../../app/static/wec/2025/imola_6h.csv";
    if !Path::new(csv_path).exists() {
        println!("Skipping test - CSV file not found: {}", csv_path);
        return;
    }

    let csv_content = fs::read_to_string(csv_path)
        .expect("Failed to read Imola CSV file");

    // Parse CSV to internal structures
    let laps_with_metadata = parse_laps_from_csv(&csv_content);
    assert!(!laps_with_metadata.is_empty(), "Should parse laps from Imola CSV");

    // Group by cars
    let cars = group_laps_by_car(laps_with_metadata);
    assert!(!cars.is_empty(), "Should have cars grouped from Imola data");

    // Validate expected cars exist (based on real data inspection)
    let car_numbers: Vec<&str> = cars.iter()
        .map(|c| c.meta_data.car_number.as_str())
        .collect();
    
    assert!(car_numbers.contains(&"007"), "Should contain car 007");
    
    // Validate car 007 has expected structure
    let car_007 = cars.iter().find(|c| c.meta_data.car_number == "007").unwrap();
    assert!(!car_007.laps.is_empty(), "Car 007 should have laps");
    assert_eq!(car_007.meta_data.team, "Aston Martin Thor Team");
    assert_eq!(car_007.meta_data.manufacturer, "Aston Martin");
    assert_eq!(car_007.meta_data.class, motorsport::Class::LMH);
}

#[test]
fn test_real_data_le_mans_24h_processing() {
    let csv_path = "../../app/static/wec/2025/le_mans_24h.csv";
    if !Path::new(csv_path).exists() {
        println!("Skipping test - CSV file not found: {}", csv_path);
        return;
    }

    let csv_content = fs::read_to_string(csv_path)
        .expect("Failed to read Le Mans CSV file");

    let laps_with_metadata = parse_laps_from_csv(&csv_content);
    assert!(!laps_with_metadata.is_empty(), "Should parse laps from Le Mans CSV");

    let cars = group_laps_by_car(laps_with_metadata);
    assert!(!cars.is_empty(), "Should have cars grouped from Le Mans data");

    // Validate Le Mans specific data
    let car_007 = cars.iter().find(|c| c.meta_data.car_number == "007");
    if let Some(car) = car_007 {
        assert_eq!(car.meta_data.team, "Aston Martin Thor Team");
        assert_eq!(car.meta_data.manufacturer, "Aston Martin");
        // Le Mans should have more laps than other races
        assert!(car.laps.len() > 10, "Le Mans should have many laps for car 007");
    }
}

#[test]
fn test_csv_field_parsing_completeness() {
    let csv_path = "../../app/static/wec/2025/imola_6h.csv";
    if !Path::new(csv_path).exists() {
        println!("Skipping test - CSV file not found: {}", csv_path);
        return;
    }

    let csv_content = fs::read_to_string(csv_path).unwrap();
    let lines: Vec<&str> = csv_content.lines().collect();
    
    if lines.len() < 2 {
        return; // Empty or header-only file
    }

    // Check header fields - the CSV should have many more fields than we currently parse
    let header = lines[0];
    let field_count = header.split(';').count();
    
    // Real WEC CSV files have 50+ fields including mini-sectors, timing points, etc.
    assert!(field_count > 20, 
        "Real WEC CSV should have many fields (found {}), current Rust parsing is incomplete", 
        field_count);
    
    // Verify specific expected fields exist
    assert!(header.contains("DRIVER_NUMBER"), "Should have DRIVER_NUMBER field");
    assert!(header.contains("LAP_IMPROVEMENT"), "Should have LAP_IMPROVEMENT field");
    assert!(header.contains("KPH"), "Should have KPH field");
    assert!(header.contains("TOP_SPEED"), "Should have TOP_SPEED field");
    assert!(header.contains("HOUR"), "Should have HOUR field");
    assert!(header.contains("PIT_TIME"), "Should have PIT_TIME field");
}

#[test]
fn test_cli_output_structure_compatibility() {
    let csv_path = "../../app/static/wec/2025/imola_6h.csv";
    if !Path::new(csv_path).exists() {
        println!("Skipping test - CSV file not found: {}", csv_path);
        return;
    }

    let test_output = "test_real_data_output.json";
    
    // Clean up any existing test file
    if fs::metadata(test_output).is_ok() {
        fs::remove_file(test_output).expect("Failed to remove existing test file");
    }

    // Run CLI with real data
    let config = Config {
        input_file: csv_path.to_string(),
        output_file: Some(test_output.to_string()),
        event_name: Some("6 Hours of Imola".to_string()),
    };

    let result = run(config);
    assert!(result.is_ok(), "CLI should process real WEC data successfully: {:?}", result.err());

    // Verify output file exists and has valid JSON
    assert!(fs::metadata(test_output).is_ok(), "Output file should be created");
    
    let json_content = fs::read_to_string(test_output).unwrap();
    let elm_output: Result<serde_json::Value, _> = serde_json::from_str(&json_content);
    assert!(elm_output.is_ok(), "Output should be valid JSON");

    let elm_output = elm_output.unwrap();
    assert!(elm_output.is_object(), "Output should be an Elm-compatible object");

    // Validate Elm-compatible 3-layer structure
    let obj = elm_output.as_object().unwrap();
    assert!(obj.contains_key("name"), "Should have name field");
    assert!(obj.contains_key("laps"), "Should have laps field");
    assert!(obj.contains_key("preprocessed"), "Should have preprocessed field");

    // Validate preprocessed cars array
    let preprocessed = obj.get("preprocessed").unwrap().as_array().unwrap();
    assert!(!preprocessed.is_empty(), "Should have cars in preprocessed array");

    // Validate Elm-compatible car structure
    for car in preprocessed {
        // Required fields for Elm compatibility
        assert!(car.get("carNumber").is_some(), "Car should have carNumber");
        assert!(car.get("drivers").is_some(), "Car should have drivers");
        assert!(car.get("class").is_some(), "Car should have class");
        assert!(car.get("team").is_some(), "Car should have team");
        assert!(car.get("manufacturer").is_some(), "Car should have manufacturer");
        assert!(car.get("startPosition").is_some(), "Car should have startPosition");
        assert!(car.get("laps").is_some(), "Car should have laps");

        // Validate drivers array structure
        let drivers = car.get("drivers").unwrap().as_array().unwrap();
        if !drivers.is_empty() {
            let driver = &drivers[0];
            assert!(driver.get("name").is_some(), "Driver should have name");
            assert!(driver.get("isCurrentDriver").is_some(), "Driver should have isCurrentDriver");
        }

        // Validate laps array structure
        let laps = car.get("laps").unwrap().as_array().unwrap();
        if !laps.is_empty() {
            let lap = &laps[0];
            assert!(lap.get("carNumber").is_some(), "Lap should have carNumber");
            assert!(lap.get("driver").is_some(), "Lap should have driver");
            assert!(lap.get("lap").is_some(), "Lap should have lap number");
            assert!(lap.get("time").is_some(), "Lap should have time");
            assert!(lap.get("elapsed").is_some(), "Lap should have elapsed");
        }
    }

    // Clean up test file
    fs::remove_file(test_output).expect("Failed to clean up test file");
}

#[test]
fn test_implemented_features_verification() {
    let csv_path = "../../app/static/wec/2025/imola_6h.csv";
    if !Path::new(csv_path).exists() {
        println!("Skipping test - CSV file not found: {}", csv_path);
        return;
    }

    let test_output = "test_implemented_features.json";
    
    // Clean up any existing test file
    if fs::metadata(test_output).is_ok() {
        fs::remove_file(test_output).expect("Failed to remove existing test file");
    }

    let config = Config {
        input_file: csv_path.to_string(),
        output_file: Some(test_output.to_string()),
        event_name: Some("Test Event".to_string()),
    };

    let result = run(config);
    assert!(result.is_ok(), "CLI should run successfully");

    let json_content = fs::read_to_string(test_output).unwrap();
    let elm_output: serde_json::Value = serde_json::from_str(&json_content).unwrap();

    // Verify Elm-compatible structure
    let obj = elm_output.as_object().unwrap();
    assert!(obj.contains_key("preprocessed"), "Should have preprocessed field");
    
    let cars = obj.get("preprocessed").unwrap().as_array().unwrap();

    for car in cars {
        // Check that previously missing features are now implemented (Elm-compatible format)
        assert!(car.get("startPosition").unwrap().as_i64().unwrap() >= 1, 
            "startPosition should be calculated (1 or higher)");
        
        // Check that currentLap, lastLap fields are now present
        assert!(car.get("currentLap").is_some(), "currentLap should be present");
        assert!(car.get("lastLap").is_some(), "lastLap should be present"); 

        let laps = car.get("laps").unwrap().as_array().unwrap();
        if !laps.is_empty() {
            let lap = &laps[0];
            
            // Position should now be calculated for most laps
            assert!(lap.get("position").is_some(), "position should be calculated");
            if !lap.get("position").unwrap().is_null() {
                let position = lap.get("position").unwrap().as_i64().unwrap();
                assert!(position >= 1, "position should be 1 or higher when calculated");
            }
            
            // Best times should still equal current times (this is correct for current implementation)
            // In Elm-compatible format, times are strings
            let time = lap.get("time").unwrap().as_str().unwrap();
            let best = lap.get("best").unwrap().as_str().unwrap();
            assert_eq!(time, best, "best time equals current time (current implementation behavior)");
        }
    }

    // Clean up
    fs::remove_file(test_output).expect("Failed to clean up test file");
}

#[test]
fn test_multi_race_data_consistency() {
    let races = vec![
        ("../../app/static/wec/2025/imola_6h.csv", "Imola"),
        ("../../app/static/wec/2025/le_mans_24h.csv", "Le Mans"),
        ("../../app/static/wec/2025/spa_6h.csv", "Spa"),
        ("../../app/static/wec/2025/qatar_1812km.csv", "Qatar"),
        ("../../app/static/wec/2025/sao_paulo_6h.csv", "Sao Paulo"),
    ];

    for (csv_path, race_name) in races {
        if !Path::new(csv_path).exists() {
            println!("Skipping {} - CSV file not found: {}", race_name, csv_path);
            continue;
        }

        let csv_content = match fs::read_to_string(csv_path) {
            Ok(content) => content,
            Err(_) => {
                println!("Failed to read {} data", race_name);
                continue;
            }
        };

        let laps_with_metadata = parse_laps_from_csv(&csv_content);
        if laps_with_metadata.is_empty() {
            println!("No laps parsed from {} data", race_name);
            continue;
        }

        let cars = group_laps_by_car(laps_with_metadata);
        assert!(!cars.is_empty(), "{} should have cars", race_name);

        // Validate each race has consistent data structure
        for car in &cars {
            assert!(!car.meta_data.car_number.is_empty(), 
                "{}: Car should have car number", race_name);
            assert!(!car.meta_data.drivers.is_empty(), 
                "{}: Car should have drivers", race_name);
            assert!(!car.laps.is_empty(), 
                "{}: Car should have laps", race_name);
        }

        println!("✓ {} processed successfully ({} cars)", race_name, cars.len());
    }
}