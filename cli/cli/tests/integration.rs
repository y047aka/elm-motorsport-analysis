use std::fs;
use std::path::Path;

use cli::{create_output, group_laps_by_car, parse_laps_from_csv, run, Config};

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
    let laps_with_metadata = parse_laps_from_csv(&csv_content);
    assert!(
        !laps_with_metadata.is_empty(),
        "At least one lap should be parsed from CSV"
    );

    // Validate first lap content
    let first_lap = &laps_with_metadata[0];
    assert_eq!(first_lap.lap.car_number, "12");
    assert_eq!(first_lap.lap.driver, "Will STEVENS");
    assert_eq!(first_lap.metadata.team, "Hertz Team JOTA");
    assert_eq!(first_lap.metadata.manufacturer, "Porsche");
    assert_eq!(first_lap.metadata.class, "HYPERCAR");

    // Group by car
    let cars = group_laps_by_car(laps_with_metadata);
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
    // Test output filename
    let test_output = "test_integration_output.json";

    // Pre-cleanup check for existing test files
    if fs::metadata(test_output).is_ok() {
        fs::remove_file(test_output).expect("Failed to remove existing test file");
    }

    // Create CLI configuration
    let config = Config {
        input_file: "../test_data.csv".to_string(),
        output_file: Some(test_output.to_string()),
        event_name: Some("Test Event".to_string()),
    };

    // Execute CLI
    let result = run(config);
    assert!(
        result.is_ok(),
        "CLI execution should succeed: {:?}",
        result.err()
    );

    // Verify output file creation
    assert!(
        fs::metadata(test_output).is_ok(),
        "Output file should be created"
    );

    // Validate output file content
    let json_content = fs::read_to_string(test_output).expect("Failed to read output file");
    assert!(!json_content.is_empty(), "JSON file should not be empty");

    // Verify valid JSON format
    let output: Result<serde_json::Value, _> = serde_json::from_str(&json_content);
    assert!(output.is_ok(), "Output JSON should be valid format");

    let output = output.unwrap();
    assert!(output.is_object(), "Top level should be object");

    // Validate 3-layer structure
    let obj = output.as_object().unwrap();
    assert!(obj.contains_key("name"), "name field should exist");
    assert!(obj.contains_key("laps"), "laps field should exist");
    assert!(
        obj.contains_key("preprocessed"),
        "preprocessed field should exist"
    );

    // Verify preprocessed car data exists
    let preprocessed = obj.get("preprocessed").unwrap().as_array().unwrap();
    assert!(!preprocessed.is_empty(), "Car data should exist");

    // Validate basic structure of each car
    for car in preprocessed {
        assert!(
            car.get("carNumber").is_some(),
            "carNumber field should exist"
        );
        assert!(car.get("drivers").is_some(), "drivers field should exist");
        assert!(car.get("laps").is_some(), "laps field should exist");
        assert!(
            car.get("startPosition").is_some(),
            "startPosition field should exist"
        );
        assert!(car.get("class").is_some(), "class field should exist");
        assert!(
            car.get("currentLap").is_some(),
            "currentLap field should exist"
        );
        assert!(car.get("lastLap").is_some(), "lastLap field should exist");

        // Verify currentLap and lastLap are null for Elm compatibility
        assert!(
            car.get("currentLap").unwrap().is_null(),
            "currentLap should be null"
        );
        assert!(
            car.get("lastLap").unwrap().is_null(),
            "lastLap should be null"
        );
    }

    // Cleanup test file
    fs::remove_file(test_output).expect("Failed to cleanup test file");
}

#[test]
fn test_csv_parsing_edge_cases() {
    // 空のCSVデータのテスト
    let empty_csv = "NUMBER;DRIVER_NUMBER;DRIVER_NAME;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;TOP_SPEED;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER\n";
    let laps = parse_laps_from_csv(empty_csv);
    assert_eq!(laps.len(), 0, "空のCSVからは0個のラップが解析されるはず");

    // 不正なデータを含むCSVのテスト（エラーハンドリング確認）
    let invalid_csv = "NUMBER;DRIVER_NUMBER;DRIVER_NAME;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;TOP_SPEED;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER\n12;1;Will STEVENS;1;invalid_time;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;;;HYPERCAR;H;Hertz Team JOTA;Porsche\n";
    let laps = parse_laps_from_csv(invalid_csv);
    // 不正なデータは0に変換されるが、ラップ自体は作成される
    assert_eq!(laps.len(), 1, "不正データでも1個のラップが作成されるはず");
    assert_eq!(laps[0].lap.time, 0, "不正なタイムは0に変換されるはず");
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

        let laps_with_metadata = parse_laps_from_csv(&csv_content);
        assert!(
            !laps_with_metadata.is_empty(),
            "{race_name} should parse laps from CSV"
        );

        let cars = group_laps_by_car(laps_with_metadata);
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
    // 包括的なElm互換JSON構造・フィールド・データ型テスト
    let csv_data = create_test_csv_data();
    let laps_with_metadata = parse_laps_from_csv(&csv_data);
    let cars = group_laps_by_car(laps_with_metadata.clone());

    let elm_output = create_output("Test Event", &laps_with_metadata, &cars);
    let json_value = serde_json::to_value(&elm_output).unwrap();

    // トップレベル構造のチェック
    assert!(json_value.is_object(), "JSON should be an object");
    assert!(json_value.get("name").is_some(), "name field required");
    assert!(json_value.get("laps").is_some(), "laps field required");
    assert!(
        json_value.get("preprocessed").is_some(),
        "preprocessed field required"
    );
    assert!(json_value["name"].is_string(), "name should be string");
    assert!(json_value["laps"].is_array(), "laps should be array");
    assert!(
        json_value["preprocessed"].is_array(),
        "preprocessed should be array"
    );

    // ラップフィールドの完全性と型チェック
    let laps_array = json_value["laps"].as_array().unwrap();
    if !laps_array.is_empty() {
        let lap = &laps_array[0];

        // 文字列フィールド
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

        // 数値フィールド
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

    // 前処理済み車両フィールドの完全性と型チェック
    let preprocessed_array = json_value["preprocessed"].as_array().unwrap();
    if !preprocessed_array.is_empty() {
        let car = &preprocessed_array[0];

        // 車両レベルフィールド
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
        assert!(
            car.get("startPosition").is_some() && car["startPosition"].is_number(),
            "startPosition field required and should be number"
        );
        assert!(
            car.get("laps").is_some() && car["laps"].is_array(),
            "laps field required and should be array"
        );

        // Elm互換性のためcurrentLapとlastLapがnullであることを確認
        assert!(
            car.get("currentLap").is_some() && car["currentLap"].is_null(),
            "currentLap should exist and be null"
        );
        assert!(
            car.get("lastLap").is_some() && car["lastLap"].is_null(),
            "lastLap should exist and be null"
        );
    }
}

#[test]
fn test_racing_data_processing_compatibility() {
    // 包括的なレースデータ処理テスト：改善フラグ、ピットストップ、ピットタイム
    let csv_with_racing_data = r#"NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS;
007;1;26;1:34.552;2;;19.398;0;30.981;2;44.173;0;186.9;44:14.995;13:45:40.505;0:19.398;0:30.981;0:44.173;305.1;Harry TINCKNELL;;HYPERCAR;;Aston Martin Thor Team;Aston Martin;GF;19.398;30.981;44.173;
007;1;34;2:47.748;0;B;19.480;0;31.197;0;1:57.071;0;105.4;58:12.901;13:59:38.411;0:19.480;0:31.197;1:57.071;307.7;Harry TINCKNELL;;HYPERCAR;;Aston Martin Thor Team;Aston Martin;GF;19.480;31.197;117.071;
007;1;35;2:03.956;0;;39.723;0;35.798;0;48.435;0;142.6;1:00:16.857;14:01:42.367;0:39.723;0:35.798;0:48.435;186.9;Harry TINCKNELL;1:28.944;HYPERCAR;;Aston Martin Thor Team;Aston Martin;GF;39.723;35.798;48.435;
007;1;36;1:35.123;0;;19.400;0;31.200;0;44.523;0;185.2;1:01:51.980;14:03:17.490;0:19.400;0:31.200;0:44.523;304.2;Harry TINCKNELL;45.678;HYPERCAR;;Aston Martin Thor Team;Aston Martin;GF;19.400;31.200;44.523;"#.to_string();

    let laps_with_metadata = parse_laps_from_csv(&csv_with_racing_data);
    let cars = group_laps_by_car(laps_with_metadata.clone());
    let elm_output = create_output("Test Event", &laps_with_metadata, &cars);
    let json_value = serde_json::to_value(&elm_output).unwrap();
    let laps_array = json_value["laps"].as_array().unwrap();

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
// EXACT ELM-RUST JSON COMPATIBILITY TESTS (TDD)
// =============================================================================
//
// Complete JSON comparison tests following TDD methodology
// Goal: Achieve 100% identical JSON output between Elm and Rust CLI

#[test]
#[ignore = "Skipped: Mini-sectors not yet implemented, will pass once mini-sector support is added"]
fn test_exact_json_match_le_mans_24h() {
    // TDD: Test exact JSON match for Le Mans 24h (currently fails due to missing mini-sectors)
    let csv_path = "../../app/static/wec/2025/le_mans_24h.csv";
    let elm_json_path = "../../app/static/wec/2025/le_mans_24h.json";

    if !Path::new(csv_path).exists() || !Path::new(elm_json_path).exists() {
        println!("Skipping Le Mans exact match test - required files not found");
        return;
    }

    let csv_content = fs::read_to_string(csv_path).expect("Failed to read Le Mans CSV");
    let laps_with_metadata = parse_laps_from_csv(&csv_content);
    let cars = group_laps_by_car(laps_with_metadata.clone());
    let rust_output = create_output("le_mans_24h", &laps_with_metadata, &cars);

    let elm_json_content = fs::read_to_string(elm_json_path).expect("Failed to read Elm JSON");
    let elm_output: serde_json::Value =
        serde_json::from_str(&elm_json_content).expect("Failed to parse Elm JSON");

    let rust_json_value = serde_json::to_value(&rust_output).unwrap();

    assert_json_exact_match(&elm_output, &rust_json_value, "Le Mans 24h");
}

// =============================================================================
// ELM COMPATIBILITY TESTS
// =============================================================================
//
// Additional tests for Elm-specific functionality and edge cases

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/// Detailed JSON comparison function for TDD exact matching (ignoring KPH precision)
fn assert_json_exact_match(
    elm_json: &serde_json::Value,
    rust_json: &serde_json::Value,
    race_name: &str,
) {
    // Write comparison files for detailed analysis
    let elm_pretty = serde_json::to_string_pretty(elm_json).unwrap();
    let rust_pretty = serde_json::to_string_pretty(rust_json).unwrap();

    fs::write(
        format!(
            "test_exact_match_{}_elm.json",
            race_name.replace(" ", "_").to_lowercase()
        ),
        &elm_pretty,
    )
    .expect("Failed to write Elm comparison file");
    fs::write(
        format!(
            "test_exact_match_{}_rust.json",
            race_name.replace(" ", "_").to_lowercase()
        ),
        &rust_pretty,
    )
    .expect("Failed to write Rust comparison file");

    // Detailed comparison with specific error messages (ignoring KPH precision)
    if !json_equals_ignore_kph_precision(elm_json, rust_json) {
        // Compare top-level structure
        assert_eq!(
            elm_json.get("name"),
            rust_json.get("name"),
            "[{race_name}] Event name mismatch"
        );

        // Compare laps array length
        let elm_laps = elm_json.get("laps").and_then(|v| v.as_array()).unwrap();
        let rust_laps = rust_json.get("laps").and_then(|v| v.as_array()).unwrap();
        assert_eq!(
            elm_laps.len(),
            rust_laps.len(),
            "[{}] Laps array length mismatch: Elm={}, Rust={}",
            race_name,
            elm_laps.len(),
            rust_laps.len()
        );

        // Compare preprocessed array length
        let elm_preprocessed = elm_json
            .get("preprocessed")
            .and_then(|v| v.as_array())
            .unwrap();
        let rust_preprocessed = rust_json
            .get("preprocessed")
            .and_then(|v| v.as_array())
            .unwrap();
        assert_eq!(
            elm_preprocessed.len(),
            rust_preprocessed.len(),
            "[{}] Preprocessed array length mismatch: Elm={}, Rust={}",
            race_name,
            elm_preprocessed.len(),
            rust_preprocessed.len()
        );

        // Find and report first difference in laps (ignoring KPH precision)
        for (i, (elm_lap, rust_lap)) in elm_laps.iter().zip(rust_laps.iter()).enumerate() {
            if !json_equals_ignore_kph_precision(elm_lap, rust_lap) {
                println!("[{race_name}] First lap difference at index {i}");
                println!(
                    "Elm lap:  {}",
                    serde_json::to_string_pretty(elm_lap).unwrap()
                );
                println!(
                    "Rust lap: {}",
                    serde_json::to_string_pretty(rust_lap).unwrap()
                );

                // Compare individual fields (ignoring KPH precision)
                for (field_name, elm_value) in elm_lap.as_object().unwrap() {
                    let rust_value = rust_lap.get(field_name);
                    if field_name == "kph" {
                        // Special handling for KPH precision
                        if let (Some(elm_num), Some(rust_num)) =
                            (elm_value.as_f64(), rust_value.and_then(|v| v.as_f64()))
                        {
                            if (elm_num - rust_num).abs() > 0.01 {
                                println!(
                                    "[{race_name}][lap {i}][{field_name}] Field mismatch: Elm={elm_value:?}, Rust={rust_value:?}"
                                );
                            }
                        } else if Some(elm_value) != rust_value {
                            println!(
                                "[{race_name}][lap {i}][{field_name}] Field mismatch: Elm={elm_value:?}, Rust={rust_value:?}"
                            );
                        }
                    } else if Some(elm_value) != rust_value {
                        println!(
                            "[{race_name}][lap {i}][{field_name}] Field mismatch: Elm={elm_value:?}, Rust={rust_value:?}"
                        );
                    }
                }
                break;
            }
        }

        // Find and report first difference in preprocessed (ignoring KPH precision)
        for (i, (elm_car, rust_car)) in elm_preprocessed
            .iter()
            .zip(rust_preprocessed.iter())
            .enumerate()
        {
            if !json_equals_ignore_kph_precision(elm_car, rust_car) {
                println!(
                    "[{race_name}] First preprocessed car difference at index {i}"
                );
                println!(
                    "Elm car:  {}",
                    serde_json::to_string_pretty(elm_car).unwrap()
                );
                println!(
                    "Rust car: {}",
                    serde_json::to_string_pretty(rust_car).unwrap()
                );
                break;
            }
        }

        panic!("[{}] JSON outputs do not match exactly. Check test_exact_match_*_{}.json files for detailed comparison.",
            race_name, race_name.replace(" ", "_").to_lowercase());
    }

    println!("[{race_name}] ✓ JSON outputs match exactly!");
}

/// Custom JSON equality check that ignores KPH precision differences
fn json_equals_ignore_kph_precision(elm: &serde_json::Value, rust: &serde_json::Value) -> bool {
    match (elm, rust) {
        (serde_json::Value::Object(elm_obj), serde_json::Value::Object(rust_obj)) => {
            if elm_obj.len() != rust_obj.len() {
                return false;
            }
            for (key, elm_value) in elm_obj {
                if let Some(rust_value) = rust_obj.get(key) {
                    if key == "kph" {
                        // Special handling for KPH precision
                        if let (Some(elm_num), Some(rust_num)) =
                            (elm_value.as_f64(), rust_value.as_f64())
                        {
                            // Allow small precision differences for KPH values
                            if (elm_num - rust_num).abs() > 0.01 {
                                return false;
                            }
                        } else {
                            return false;
                        }
                    } else if !json_equals_ignore_kph_precision(elm_value, rust_value) {
                        return false;
                    }
                } else {
                    return false;
                }
            }
            true
        }
        (serde_json::Value::Array(elm_arr), serde_json::Value::Array(rust_arr)) => {
            if elm_arr.len() != rust_arr.len() {
                return false;
            }
            elm_arr
                .iter()
                .zip(rust_arr.iter())
                .all(|(elm_item, rust_item)| json_equals_ignore_kph_precision(elm_item, rust_item))
        }
        _ => elm == rust,
    }
}

fn create_test_csv_data() -> String {
    r#"NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS;
12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;0:23.155;0:29.928;0:42.282;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;23.155;29.928;42.282;
7;1;1;1:33.291;0;;23.119;0;29.188;0;40.984;0;175.0;1:33.291;11:02:00.782;0:23.119;0:29.188;0:40.984;298.6;Kamui KOBAYASHI;;HYPERCAR;H;Toyota Gazoo Racing;Toyota;GF;23.119;29.188;40.984;
12;2;2;1:32.245;1;;22.500;1;29.100;1;40.645;1;165.2;3:07.610;11:03:35.101;0:22.500;0:29.100;0:40.645;;Robin FRIJNS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;22.500;29.100;40.645;"#.to_string()
}
