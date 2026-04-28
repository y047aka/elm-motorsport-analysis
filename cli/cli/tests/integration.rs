use std::fs;
use std::path::Path;

use cli::for_testing::{build_outputs, group_laps_by_car, parse_and_structure};

// =============================================================================
// INTEGRATION TESTS
// =============================================================================
//
// Test Suite Overview:
// 1. Core CSV Processing & CLI Integration (4 tests)
// 2. Elm-Rust JSON Compatibility (2 tests - consolidated, duplicates moved to unit tests)
// 3. Le Mans 24h JSON Exact Match (1 test - includes mini-sectors)
//
// Total: 7 focused tests covering all critical functionality
// Optimized by moving low-level functionality to appropriate unit tests

#[test]
fn test_csv_parsing_and_data_processing() {
    // CSV reading and parsing (integrated)
    let csv_content = fs::read_to_string("../test_data.csv").expect("Failed to read CSV file");
    let records = parse_and_structure(&csv_content);
    assert!(
        !records.is_empty(),
        "At least one lap should be parsed from CSV"
    );

    // Validate first lap content
    let first_lap = &records[0];
    assert_eq!(first_lap.lap.car_number, "12");
    assert_eq!(first_lap.lap.driver, "Will STEVENS");
    assert_eq!(first_lap.car.team, "Hertz Team JOTA");
    assert_eq!(first_lap.car.manufacturer, "Porsche");
    assert_eq!(first_lap.car.class, "HYPERCAR");

    // Group by car
    let cars = group_laps_by_car(records);
    assert_eq!(cars.len(), 2, "Test data should contain 2 cars");

    // Validate car 12
    let car12 = cars
        .iter()
        .find(|c| c.meta_data.car_number == "12")
        .unwrap();
    assert!(car12.laps.len() >= 2, "Car 12 should have multiple laps");
    assert_eq!(car12.meta_data.team, "Hertz Team JOTA");
    assert_eq!(car12.meta_data.manufacturer, "Porsche");

    // Validate car 7
    let car7 = cars.iter().find(|c| c.meta_data.car_number == "7").unwrap();
    assert!(!car7.laps.is_empty(), "Car 7 should have at least one lap");
    assert_eq!(car7.meta_data.team, "Toyota Gazoo Racing");
    assert_eq!(car7.meta_data.manufacturer, "Toyota");

    // Validate lap data consistency and position calculations
    for car in &cars {
        assert!(!car.laps.is_empty(), "Each car should have lap data");
        assert!(
            car.start_position >= 0,
            "Start position should be non-negative"
        );

        for lap in &car.laps {
            assert!(lap.time > 0, "Lap time should be positive");
            assert!(lap.sector_1 > 0, "Sector 1 should be positive");
            assert!(lap.sector_2 > 0, "Sector 2 should be positive");
            assert!(lap.sector_3 > 0, "Sector 3 should be positive");
            // position is u32 type, so always >= 0 - no explicit check needed
        }
    }
}

#[test]
fn test_cli_end_to_end_execution() {
    // Use tempdir to isolate test files and avoid races across parallel tests
    let temp_dir = tempfile::tempdir().expect("create tempdir");
    let test_input = temp_dir.path().join("input.csv");
    let test_output = temp_dir.path().join("output.json");
    let test_input_str = test_input.to_str().expect("UTF-8 path");
    let test_output_str = test_output.to_str().expect("UTF-8 path");

    // Copy test data to expected input filename
    fs::copy("../test_data.csv", &test_input).expect("Failed to copy test data");

    // Execute CLI via argv
    let args = vec![
        "cli".to_string(),
        test_input_str.to_string(),
        "--output".to_string(),
        test_output_str.to_string(),
    ];
    let summary = cli::run(args.into_iter()).expect("CLI should accept the arguments");
    assert_eq!(summary.errors, 0, "CLI should process without errors");
    assert_eq!(summary.processed, 1, "one task should succeed");

    // Verify output file creation
    assert!(
        fs::metadata(&test_output).is_ok(),
        "Output file should be created"
    );

    // Validate output file content
    let json_content = fs::read_to_string(&test_output).expect("Failed to read output file");
    assert!(!json_content.is_empty(), "JSON file should not be empty");

    // Verify valid JSON format
    let output: Result<serde_json::Value, _> = serde_json::from_str(&json_content);
    assert!(output.is_ok(), "Output JSON should be valid format");

    let output = output.unwrap();
    assert!(output.is_object(), "Top level should be object");

    // Validate metadata structure (name, startingGrid)
    let obj = output.as_object().unwrap();
    assert!(obj.contains_key("name"), "name field should exist");
    assert!(
        obj.contains_key("startingGrid"),
        "startingGrid field should exist"
    );

    // Verify that laps field is NOT in metadata file (moved to separate laps file)
    assert!(
        !obj.contains_key("laps"),
        "laps field should NOT exist in metadata file"
    );

    // Verify starting grid data exists
    let starting_grid = obj.get("startingGrid").unwrap().as_array().unwrap();
    assert!(!starting_grid.is_empty(), "Car data should exist");

    // Validate basic structure of each starting grid entry
    for grid_entry in starting_grid {
        assert!(
            grid_entry.get("position").is_some(),
            "position field should exist"
        );
        assert!(grid_entry.get("car").is_some(), "car field should exist");
        let car = grid_entry.get("car").unwrap();
        assert!(
            car.get("carNumber").is_some(),
            "carNumber field should exist"
        );
        assert!(car.get("drivers").is_some(), "drivers field should exist");
        assert!(car.get("class").is_some(), "class field should exist");
    }

    // Verify laps data file exists and has correct structure
    let laps_output_path = test_output.with_file_name("output_laps.json");
    assert!(
        fs::metadata(&laps_output_path).is_ok(),
        "Laps data file should exist"
    );

    let laps_json_content =
        fs::read_to_string(&laps_output_path).expect("Failed to read laps data file");

    let laps_output: Result<serde_json::Value, _> = serde_json::from_str(&laps_json_content);
    assert!(laps_output.is_ok(), "Laps data JSON should be valid format");

    let laps_binding = laps_output.unwrap();
    let laps = laps_binding.as_array().unwrap();

    assert!(!laps.is_empty(), "laps array should not be empty");

    // Validate first lap structure
    let first_lap = laps[0].as_object().unwrap();
    assert!(
        first_lap.contains_key("carNumber"),
        "carNumber field should exist"
    );
    assert!(
        first_lap.contains_key("driverName"),
        "driverName field should exist"
    );
    assert!(
        first_lap.contains_key("lapNumber"),
        "lapNumber field should exist"
    );
    assert!(
        first_lap.contains_key("lapTime"),
        "lapTime field should exist"
    );
    assert!(
        first_lap.contains_key("elapsed"),
        "elapsed field should exist"
    );
    assert!(first_lap.contains_key("kph"), "kph field should exist");
    assert!(first_lap.contains_key("class"), "class field should exist");
    assert!(first_lap.contains_key("team"), "team field should exist");
    assert!(
        first_lap.contains_key("manufacturer"),
        "manufacturer field should exist"
    );

    // tempdir cleans up on drop
}

#[test]
fn test_cli_run_reports_partial_failure() {
    // Verify `run` correctly accounts for mixed success/failure and that
    // `exit_code()` returns FAILURE when any file failed.
    //
    // An "unreadable .csv" is represented by a **directory** whose name ends
    // in `.csv`. `parse_args`'s walkdir only filters by extension and doesn't
    // check `is_file`, so the directory is enumerated as a task. The
    // downstream `files::read_csv` then fails with `FileError::ReadFile` when
    // it tries to `read_to_string` a directory.
    let temp_dir = tempfile::tempdir().expect("create tempdir");

    // Entry 1: a real CSV that should process cleanly.
    let valid_csv = temp_dir.path().join("valid.csv");
    fs::copy("../test_data.csv", &valid_csv).expect("Failed to copy test data");

    // Entry 2: a directory ending in `.csv` — reading will fail.
    let broken_csv_dir = temp_dir.path().join("broken.csv");
    fs::create_dir(&broken_csv_dir).expect("create broken.csv as directory");

    let args = vec![
        "cli".to_string(),
        temp_dir.path().to_str().expect("UTF-8 path").to_string(),
    ];
    let summary = cli::run(args.into_iter()).expect("parse_args succeeds (path is a directory)");

    assert_eq!(summary.processed, 1, "exactly valid.csv should succeed");
    assert_eq!(
        summary.errors, 1,
        "exactly the broken.csv directory should fail"
    );

    // ExitCode doesn't implement PartialEq, so compare via the Debug string.
    let exit = summary.exit_code();
    assert!(
        format!("{exit:?}").contains("1"),
        "exit_code() should be FAILURE (1): {exit:?}"
    );
}

#[test]
fn test_csv_parsing_edge_cases() {
    // Empty CSV: header only, no rows.
    let empty_csv = "NUMBER;DRIVER_NUMBER;DRIVER_NAME;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;TOP_SPEED;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER\n";
    let laps = parse_and_structure(empty_csv);
    assert_eq!(laps.len(), 0, "empty CSV should parse to zero laps");

    // Non-empty but unparseable LAP_TIME: still produces a lap, with a warning
    // logged by stages::structure::parse_required_durations and `time` falling
    // back to 0.
    let invalid_csv = "NUMBER;DRIVER_NUMBER;DRIVER_NAME;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;TOP_SPEED;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER\n12;1;Will STEVENS;1;invalid_time;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;;;HYPERCAR;H;Hertz Team JOTA;Porsche\n";
    let laps = parse_and_structure(invalid_csv);
    assert_eq!(laps.len(), 1, "invalid data still produces one lap");
    assert_eq!(laps[0].lap.time, 0, "unparseable time falls back to 0");
}

#[test]
fn test_real_wec_data_processing() {
    let test_files = vec![(
        "../../app/static/wec/2025/le_mans_24h.csv",
        "Le Mans",
        50,
        "007",
        "Aston Martin Thor Team",
    )];

    for (csv_path, race_name, min_cars, test_car, expected_team) in test_files {
        if !Path::new(csv_path).exists() {
            println!("Skipping {race_name} - CSV file not found: {csv_path}");
            continue;
        }

        let csv_content = fs::read_to_string(csv_path)
            .unwrap_or_else(|_| panic!("Failed to read CSV for {race_name}"));

        let records = parse_and_structure(&csv_content);
        assert!(
            !records.is_empty(),
            "{race_name} should parse laps from CSV"
        );

        let cars = group_laps_by_car(records);
        assert!(!cars.is_empty(), "{race_name} should have cars grouped");
        assert!(
            cars.len() >= min_cars,
            "{race_name} should have at least {min_cars} cars"
        );

        // Test specific car exists and has expected data
        if let Some(test_car_data) = cars.iter().find(|c| c.meta_data.car_number == test_car) {
            assert!(
                !test_car_data.laps.is_empty(),
                "{race_name}: Car {test_car} should have laps"
            );
            assert_eq!(
                test_car_data.meta_data.team, expected_team,
                "{race_name}: Car {test_car} should have correct team"
            );
        }

        // Validate all cars have consistent structure
        for car in &cars {
            assert!(
                !car.meta_data.car_number.is_empty(),
                "{race_name}: Car should have number"
            );
            assert!(
                !car.meta_data.drivers.is_empty(),
                "{race_name}: Car should have drivers"
            );
            assert!(!car.laps.is_empty(), "{race_name}: Car should have laps");
            assert!(
                car.start_position >= 0,
                "{race_name}: Car should have valid start position"
            );

            for lap in &car.laps {
                assert!(lap.time > 0, "{race_name}: Lap should have positive time");
                assert!(
                    lap.elapsed > 0,
                    "{race_name}: Lap should have positive elapsed time"
                );
            }
        }

        println!(
            "✓ {} processed successfully: {} cars, {} total laps",
            race_name,
            cars.len(),
            cars.iter().map(|c| c.laps.len()).sum::<usize>()
        );
    }
}

// =============================================================================
// ELM-RUST JSON COMPATIBILITY TESTS
// =============================================================================
//
// Core compatibility test suite ensuring Rust CLI output matches Elm expectations.
// Covers: structure, data types, field ordering, precision, edge cases

#[test]
fn test_elm_json_structure_and_field_compatibility() {
    // End-to-end check of JSON structure, field presence, and types that the
    // Elm frontend expects.
    let csv_data = create_test_csv_data();
    let records = parse_and_structure(&csv_data);

    let (laps_output, metadata_output) = build_outputs(records, "Test Event");
    let metadata_json_value = serde_json::to_value(&metadata_output).unwrap();
    let laps_json_value = serde_json::to_value(&laps_output).unwrap();

    // Metadata JSON structure.
    assert!(
        metadata_json_value.is_object(),
        "Metadata JSON should be an object"
    );
    assert!(
        metadata_json_value.get("name").is_some(),
        "name field required"
    );
    assert!(
        metadata_json_value.get("startingGrid").is_some(),
        "startingGrid field required"
    );

    // Laps JSON is a bare array.
    assert!(laps_json_value.is_array(), "Laps JSON should be an array");
    assert!(
        metadata_json_value["name"].is_string(),
        "name should be string"
    );
    assert!(
        metadata_json_value["startingGrid"].is_array(),
        "startingGrid should be array"
    );

    // Lap field completeness + types.
    let laps_array = laps_json_value.as_array().unwrap();
    if !laps_array.is_empty() {
        let lap = &laps_array[0];

        let string_fields = [
            "carNumber",
            "lapTime",
            "crossingFinishLineInPit",
            "s1",
            "s2",
            "s3",
            "elapsed",
            "hour",
            "topSpeed",
            "driverName",
            "pitTime",
            "class",
            "group",
            "team",
            "manufacturer",
        ];
        for field in &string_fields {
            assert!(lap.get(field).is_some(), "{field} field required");
            assert!(lap[field].is_string(), "{field} should be string");
        }

        let number_fields = [
            "driverNumber",
            "lapNumber",
            "lapImprovement",
            "s1Improvement",
            "s2Improvement",
            "s3Improvement",
            "kph",
        ];
        for field in &number_fields {
            assert!(lap.get(field).is_some(), "{field} field required");
            assert!(lap[field].is_number(), "{field} should be number");
        }
    }

    // Starting-grid field completeness + types.
    let starting_grid_array = metadata_json_value["startingGrid"].as_array().unwrap();
    if !starting_grid_array.is_empty() {
        let grid_entry = &starting_grid_array[0];

        assert!(
            grid_entry.get("position").is_some() && grid_entry["position"].is_number(),
            "position field required and should be number"
        );
        assert!(
            grid_entry.get("car").is_some() && grid_entry["car"].is_object(),
            "car field required and should be object"
        );

        let car = &grid_entry["car"];

        assert!(
            car.get("carNumber").is_some() && car["carNumber"].is_string(),
            "carNumber field required and should be string"
        );
        assert!(
            car.get("drivers").is_some() && car["drivers"].is_array(),
            "drivers field required and should be array"
        );
        assert!(
            car.get("class").is_some() && car["class"].is_string(),
            "class field required and should be string"
        );
    }
}

#[test]
fn test_racing_data_processing_compatibility() {
    // End-to-end race-data processing: improvement flags, pit-entry marker,
    // and pit-time formatting.
    let csv_with_racing_data = r#"NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS;
007;1;26;1:34.552;2;;19.398;0;30.981;2;44.173;0;186.9;44:14.995;13:45:40.505;0:19.398;0:30.981;0:44.173;305.1;Harry TINCKNELL;;HYPERCAR;;Aston Martin Thor Team;Aston Martin;GF;19.398;30.981;44.173;
007;1;34;2:47.748;0;B;19.480;0;31.197;0;1:57.071;0;105.4;58:12.901;13:59:38.411;0:19.480;0:31.197;1:57.071;307.7;Harry TINCKNELL;;HYPERCAR;;Aston Martin Thor Team;Aston Martin;GF;19.480;31.197;117.071;
007;1;35;2:03.956;0;;39.723;0;35.798;0;48.435;0;142.6;1:00:16.857;14:01:42.367;0:39.723;0:35.798;0:48.435;186.9;Harry TINCKNELL;1:28.944;HYPERCAR;;Aston Martin Thor Team;Aston Martin;GF;39.723;35.798;48.435;
007;1;36;1:35.123;0;;19.400;0;31.200;0;44.523;0;185.2;1:01:51.980;14:03:17.490;0:19.400;0:31.200;0:44.523;304.2;Harry TINCKNELL;45.678;HYPERCAR;;Aston Martin Thor Team;Aston Martin;GF;19.400;31.200;44.523;"#.to_string();

    let records = parse_and_structure(&csv_with_racing_data);
    let (laps_output, _) = build_outputs(records, "Test Event");
    let json_value = serde_json::to_value(&laps_output).unwrap();
    let laps_array = json_value.as_array().unwrap();

    // Improvement flag test (0, 1, 2)
    let lap_with_improvement = laps_array
        .iter()
        .find(|lap| lap["lapImprovement"].as_i64() == Some(2))
        .expect("Should find lap with improvement flag 2");
    assert_eq!(lap_with_improvement["lapImprovement"].as_i64(), Some(2));
    assert_eq!(lap_with_improvement["s2Improvement"].as_i64(), Some(2));

    // Pit stop data test
    let pit_entry_lap = laps_array
        .iter()
        .find(|lap| lap["crossingFinishLineInPit"].as_str() == Some("B"))
        .expect("Should find pit entry lap");
    assert_eq!(pit_entry_lap["crossingFinishLineInPit"].as_str(), Some("B"));
    assert!(pit_entry_lap["lapTime"].as_str().unwrap().starts_with("2:"));

    // Pit time processing test (format only, details covered by duration unit tests)
    let pit_exit_lap = laps_array
        .iter()
        .find(|lap| !lap["pitTime"].as_str().unwrap_or("").is_empty())
        .expect("Should find lap with pit time");
    assert!(
        !pit_exit_lap["pitTime"].as_str().unwrap().is_empty(),
        "Pit time should be formatted as non-empty string"
    );
}

// =============================================================================
// ELM COMPATIBILITY TESTS
// =============================================================================
//
// Additional tests for Elm-specific functionality and edge cases

// =============================================================================
// VALIDATION FLAG TESTS
// =============================================================================

#[test]
fn cli_validate_flag_passes_for_clean_test_data() {
    // The bundled test_data.csv was hand-verified to satisfy all three
    // validation rules: sectors sum to lap_time, elapsed accumulates lap times,
    // and (hour - elapsed) is constant across laps.
    let temp_dir = tempfile::tempdir().expect("create tempdir");
    let test_input = temp_dir.path().join("input.csv");
    let test_output = temp_dir.path().join("output.json");

    fs::copy("../test_data.csv", &test_input).expect("Failed to copy test data");

    let args = vec![
        "cli".to_string(),
        test_input.to_str().expect("UTF-8 path").to_string(),
        "--output".to_string(),
        test_output.to_str().expect("UTF-8 path").to_string(),
        "--validate".to_string(),
    ];
    let summary = cli::run(args.into_iter()).expect("CLI should accept the arguments");
    assert_eq!(summary.errors, 0, "clean data should produce no errors");
    assert_eq!(summary.processed, 1);
}

#[test]
fn cli_validate_flag_fails_when_data_inconsistent_but_writes_json() {
    // Synthesize a CSV where lap-2 elapsed is 100 ms ahead of the running sum.
    // The CLI must write JSON output AND report a validation failure.
    let temp_dir = tempfile::tempdir().expect("create tempdir");
    let test_input = temp_dir.path().join("input.csv");
    let test_output = temp_dir.path().join("output.json");

    let inconsistent_csv = "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER\n\
12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche\n\
12;1;2;1:53.610;0;;26.770;0;29.296;0;57.544;0;144.6;3:29.075;11:03:56.466;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche\n";
    fs::write(&test_input, inconsistent_csv).expect("write csv");

    let args = vec![
        "cli".to_string(),
        test_input.to_str().expect("UTF-8 path").to_string(),
        "--output".to_string(),
        test_output.to_str().expect("UTF-8 path").to_string(),
        "--validate".to_string(),
    ];
    let summary = cli::run(args.into_iter()).expect("CLI should accept the arguments");
    assert_eq!(summary.errors, 1, "inconsistent data should fail validation");
    assert_eq!(summary.processed, 0);

    // JSON output must still be on disk.
    assert!(
        fs::metadata(&test_output).is_ok(),
        "metadata JSON should be written even when validation fails"
    );
    let laps_path = test_output.with_file_name("output_laps.json");
    assert!(
        fs::metadata(&laps_path).is_ok(),
        "laps JSON should be written even when validation fails"
    );

    let exit = summary.exit_code();
    assert!(
        format!("{exit:?}").contains("1"),
        "exit_code() should be FAILURE: {exit:?}"
    );
}

#[test]
fn cli_without_validate_flag_passes_inconsistent_data() {
    // Same inconsistent CSV; without --validate the CLI must succeed.
    let temp_dir = tempfile::tempdir().expect("create tempdir");
    let test_input = temp_dir.path().join("input.csv");
    let test_output = temp_dir.path().join("output.json");

    let inconsistent_csv = "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER\n\
12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche\n\
12;1;2;1:53.610;0;;26.770;0;29.296;0;57.544;0;144.6;3:29.075;11:03:56.466;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche\n";
    fs::write(&test_input, inconsistent_csv).expect("write csv");

    let args = vec![
        "cli".to_string(),
        test_input.to_str().expect("UTF-8 path").to_string(),
        "--output".to_string(),
        test_output.to_str().expect("UTF-8 path").to_string(),
    ];
    let summary = cli::run(args.into_iter()).expect("CLI should accept the arguments");
    assert_eq!(summary.errors, 0);
    assert_eq!(summary.processed, 1);
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

fn create_test_csv_data() -> String {
    r#"NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS;
12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;0:23.155;0:29.928;0:42.282;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;23.155;29.928;42.282;
7;1;1;1:33.291;0;;23.119;0;29.188;0;40.984;0;175.0;1:33.291;11:02:00.782;0:23.119;0:29.188;0:40.984;298.6;Kamui KOBAYASHI;;HYPERCAR;H;Toyota Gazoo Racing;Toyota;GF;23.119;29.188;40.984;
12;2;2;1:32.245;1;;22.500;1;29.100;1;40.645;1;165.2;3:07.610;11:03:35.101;0:22.500;0:29.100;0:40.645;;Robin FRIJNS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;22.500;29.100;40.645;"#.to_string()
}
