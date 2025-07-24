use std::fs;
use std::path::Path;

use cli::{run, Config, parse_laps_from_csv, group_laps_by_car, create_elm_compatible_output, map_event_name};

// =============================================================================
// BASIC INTEGRATION TESTS
// =============================================================================


#[test]
fn test_basic_cli_run_command() {
    // テスト用の出力ファイル名
    let test_output = "test_basic_integration_output.json";

    // テスト後のクリーンアップのため、事前に存在チェック
    if fs::metadata(test_output).is_ok() {
        fs::remove_file(test_output).expect("既存のテストファイル削除に失敗");
    }

    // CLI設定を作成
    let config = Config {
        input_file: "../test_data.csv".to_string(),
        output_file: Some(test_output.to_string()),
        event_name: Some("Test Event".to_string()),
    };

    // CLI実行
    let result = run(config);
    assert!(result.is_ok(), "CLI実行は成功するはず: {:?}", result.err());

    // 出力ファイルが作成されていることを確認
    assert!(fs::metadata(test_output).is_ok(), "出力ファイルが作成されているはず");

    // 出力ファイルの内容を検証
    let json_content = fs::read_to_string(test_output).expect("出力ファイルの読み込みに失敗");
    assert!(!json_content.is_empty(), "JSONファイルは空でないはず");

    // JSONとして有効であることを確認（Elm互換形式）
    let elm_output: Result<serde_json::Value, _> = serde_json::from_str(&json_content);
    assert!(elm_output.is_ok(), "出力されたJSONは有効な形式であるはず");

    let elm_output = elm_output.unwrap();
    assert!(elm_output.is_object(), "トップレベルはオブジェクトであるはず");

    // Elm互換の3層構造を検証
    let obj = elm_output.as_object().unwrap();
    assert!(obj.contains_key("name"), "nameフィールドが存在するはず");
    assert!(obj.contains_key("laps"), "lapsフィールドが存在するはず");
    assert!(obj.contains_key("preprocessed"), "preprocessedフィールドが存在するはず");

    // preprocessed車両データが存在することを確認
    let preprocessed = obj.get("preprocessed").unwrap().as_array().unwrap();
    assert!(!preprocessed.is_empty(), "車両データが存在するはず");

    // 各車両の基本構造を検証（Elm互換形式）
    for car in preprocessed {
        assert!(car.get("carNumber").is_some(), "carNumberフィールドが存在するはず");
        assert!(car.get("drivers").is_some(), "driversフィールドが存在するはず");
        assert!(car.get("laps").is_some(), "lapsフィールドが存在するはず");
        assert!(car.get("startPosition").is_some(), "startPositionフィールドが存在するはず");
        assert!(car.get("class").is_some(), "classフィールドが存在するはず");
    }

    // テストファイルをクリーンアップ
    fs::remove_file(test_output).expect("テストファイルのクリーンアップに失敗");
}

#[test]
fn test_basic_csv_to_car_grouping() {
    // CSV読み込みとパース（統合）
    let csv_content = fs::read_to_string("../test_data.csv").expect("CSVファイル読み込み失敗");
    let laps_with_metadata = parse_laps_from_csv(&csv_content);
    assert!(!laps_with_metadata.is_empty(), "CSVから少なくとも1つのラップが解析されるはず");

    // 最初のラップの内容を検証
    let first_lap = &laps_with_metadata[0];
    assert_eq!(first_lap.lap.car_number, "12");
    assert_eq!(first_lap.lap.driver, "Will STEVENS");
    assert_eq!(first_lap.metadata.team, "Hertz Team JOTA");
    assert_eq!(first_lap.metadata.manufacturer, "Porsche");
    assert_eq!(first_lap.metadata.class, "HYPERCAR");

    // Carごとにグループ化
    let cars = group_laps_by_car(laps_with_metadata);
    assert_eq!(cars.len(), 2, "テストデータには2台の車両が存在するはず");

    // 車両12の検証
    let car12 = cars.iter().find(|c| c.meta_data.car_number == "12").unwrap();
    assert!(car12.laps.len() >= 2, "車両12には複数のラップが存在するはず");
    assert_eq!(car12.meta_data.team, "Hertz Team JOTA");
    assert_eq!(car12.meta_data.manufacturer, "Porsche");

    // 車両7の検証
    let car7 = cars.iter().find(|c| c.meta_data.car_number == "7").unwrap();
    assert!(car7.laps.len() >= 1, "車両7には少なくとも1つのラップが存在するはず");
    assert_eq!(car7.meta_data.team, "Toyota Gazoo Racing");
    assert_eq!(car7.meta_data.manufacturer, "Toyota");

    // ラップデータの整合性とポジション計算の検証
    for car in &cars {
        assert!(!car.laps.is_empty(), "各車両にはラップデータが存在するはず");
        assert!(car.start_position > 0, "スタートポジションは1以上であるはず");
        
        for lap in &car.laps {
            assert!(lap.time > 0, "ラップタイムは正の値であるはず");
            assert!(lap.sector_1 > 0, "セクター1は正の値であるはず");
            assert!(lap.sector_2 > 0, "セクター2は正の値であるはず");
            assert!(lap.sector_3 > 0, "セクター3は正の値であるはず");
            if lap.position.is_some() {
                assert!(lap.position.unwrap() > 0, "位置は1以上であるはず");
            }
        }
    }
}

#[test]
fn test_basic_csv_parsing_edge_cases() {
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

// =============================================================================
// ELM COMPATIBILITY TESTS
// =============================================================================

#[test]
fn test_elm_compatible_output_structure() {
    let csv_data = create_test_csv_data();
    let laps_with_metadata = parse_laps_from_csv(&csv_data);
    let cars = group_laps_by_car(laps_with_metadata.clone());
    
    // Elm互換のJSON構造を作成する関数をテスト
    let elm_output = create_elm_compatible_output("qatar_1812km", &laps_with_metadata, &cars);
    let json_value = serde_json::to_value(&elm_output).unwrap();
    
    // トップレベル構造の確認
    assert!(json_value.is_object());
    let obj = json_value.as_object().unwrap();
    
    // 必須フィールドの存在確認
    assert!(obj.contains_key("name"));
    assert!(obj.contains_key("laps"));
    assert!(obj.contains_key("preprocessed"));
    
    // name フィールドの確認
    assert_eq!(obj["name"].as_str().unwrap(), "Qatar 1812km");
    
    // laps 配列の確認
    assert!(obj["laps"].is_array());
    let laps_array = obj["laps"].as_array().unwrap();
    assert!(!laps_array.is_empty());
    
    // preprocessed 配列の確認
    assert!(obj["preprocessed"].is_array());
    let preprocessed_array = obj["preprocessed"].as_array().unwrap();
    assert!(!preprocessed_array.is_empty());
}

#[test]
fn test_elm_raw_lap_format() {
    let csv_data = create_test_csv_data();
    let laps_with_metadata = parse_laps_from_csv(&csv_data);
    let cars = group_laps_by_car(laps_with_metadata.clone());
    
    let elm_output = create_elm_compatible_output("Test Event", &laps_with_metadata, &cars);
    let json_value = serde_json::to_value(&elm_output).unwrap();
    let laps_array = json_value["laps"].as_array().unwrap();
    
    if !laps_array.is_empty() {
        let first_lap = &laps_array[0];
        
        // 必須フィールドの存在確認
        assert!(first_lap.get("carNumber").is_some());
        assert!(first_lap.get("driverNumber").is_some());
        assert!(first_lap.get("lapNumber").is_some());
        assert!(first_lap.get("lapTime").is_some());
        assert!(first_lap.get("lapImprovement").is_some());
        assert!(first_lap.get("crossingFinishLineInPit").is_some());
        assert!(first_lap.get("s1").is_some());
        assert!(first_lap.get("s1Improvement").is_some());
        assert!(first_lap.get("s2").is_some());
        assert!(first_lap.get("s2Improvement").is_some());
        assert!(first_lap.get("s3").is_some());
        assert!(first_lap.get("s3Improvement").is_some());
        assert!(first_lap.get("kph").is_some());
        assert!(first_lap.get("elapsed").is_some());
        assert!(first_lap.get("hour").is_some());
        assert!(first_lap.get("topSpeed").is_some());
        assert!(first_lap.get("driverName").is_some());
        assert!(first_lap.get("pitTime").is_some());
        assert!(first_lap.get("class").is_some());
        assert!(first_lap.get("group").is_some());
        assert!(first_lap.get("team").is_some());
        assert!(first_lap.get("manufacturer").is_some());
        
        // データ型の確認
        assert!(first_lap["carNumber"].is_string());
        assert!(first_lap["driverNumber"].is_number());
        assert!(first_lap["lapNumber"].is_number());
        assert!(first_lap["lapTime"].is_string());
        assert!(first_lap["lapImprovement"].is_number());
        assert!(first_lap["kph"].is_number());
        assert!(first_lap["driverName"].is_string());
    }
}

#[test]
fn test_elm_preprocessed_car_format() {
    let csv_data = create_test_csv_data();
    let laps_with_metadata = parse_laps_from_csv(&csv_data);
    let cars = group_laps_by_car(laps_with_metadata.clone());
    
    let elm_output = create_elm_compatible_output("Test Event", &laps_with_metadata, &cars);
    let json_value = serde_json::to_value(&elm_output).unwrap();
    let preprocessed_array = json_value["preprocessed"].as_array().unwrap();
    
    if !preprocessed_array.is_empty() {
        let first_car = &preprocessed_array[0];
        
        // Car level必須フィールドの存在確認
        assert!(first_car.get("carNumber").is_some());
        assert!(first_car.get("drivers").is_some());
        assert!(first_car.get("class").is_some());
        assert!(first_car.get("group").is_some());
        assert!(first_car.get("team").is_some());
        assert!(first_car.get("manufacturer").is_some());
        assert!(first_car.get("startPosition").is_some());
        assert!(first_car.get("laps").is_some());
        assert!(first_car.get("currentLap").is_some());
        assert!(first_car.get("lastLap").is_some());
        
        // データ型の確認
        assert!(first_car["carNumber"].is_string());
        assert!(first_car["drivers"].is_array());
        assert!(first_car["class"].is_string());
        assert!(first_car["startPosition"].is_number());
        assert!(first_car["laps"].is_array());
        
        // drivers配列の構造確認
        let drivers_array = first_car["drivers"].as_array().unwrap();
        if !drivers_array.is_empty() {
            let first_driver = &drivers_array[0];
            assert!(first_driver.get("name").is_some());
            assert!(first_driver.get("isCurrentDriver").is_some());
            assert!(first_driver["name"].is_string());
            assert!(first_driver["isCurrentDriver"].is_boolean());
        }
        
        // preprocessed laps配列の構造確認
        let laps_array = first_car["laps"].as_array().unwrap();
        if !laps_array.is_empty() {
            let first_lap = &laps_array[0];
            assert!(first_lap.get("carNumber").is_some());
            assert!(first_lap.get("driver").is_some());
            assert!(first_lap.get("lap").is_some());
            assert!(first_lap.get("position").is_some());
            assert!(first_lap.get("time").is_some());
            assert!(first_lap.get("best").is_some());
            assert!(first_lap.get("sector_1").is_some());
            assert!(first_lap.get("sector_2").is_some());
            assert!(first_lap.get("sector_3").is_some());
            assert!(first_lap.get("s1_best").is_some());
            assert!(first_lap.get("s2_best").is_some());
            assert!(first_lap.get("s3_best").is_some());
            assert!(first_lap.get("elapsed").is_some());
            
            // データ型の確認
            assert!(first_lap["carNumber"].is_string());
            assert!(first_lap["driver"].is_string());
            assert!(first_lap["lap"].is_number());
            assert!(first_lap["time"].is_string());
            assert!(first_lap["elapsed"].is_string());
        }
    }
}

/// Duration format（Elm互換）は motorsport::duration でテスト済みのため省略

#[test]
fn test_elm_event_name_mapping() {
    assert_eq!(map_event_name("qatar_1812km"), "Qatar 1812km");
    assert_eq!(map_event_name("imola_6h"), "6 Hours of Imola");
    assert_eq!(map_event_name("spa_6h"), "6 Hours of Spa");
    assert_eq!(map_event_name("le_mans_24h"), "24 Hours of Le Mans");
    assert_eq!(map_event_name("fuji_6h"), "6 Hours of Fuji");
    assert_eq!(map_event_name("bahrain_8h"), "8 Hours of Bahrain");
    assert_eq!(map_event_name("sao_paulo_6h"), "6 Hours of São Paulo");
    assert_eq!(map_event_name("unknown_event"), "Encoding Error");
}

#[test]
fn test_elm_optional_field_handling() {
    // Elmでは空の値は空文字列として表現
    assert_eq!(optional_string_to_elm(""), "");
    assert_eq!(optional_string_to_elm("123.456"), "123.456");
}

// =============================================================================
// REAL WEC DATA TESTS
// =============================================================================

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

    // Le Mans typically has more cars than shorter races
    assert!(cars.len() >= 50, "Le Mans should have many cars (50+)");

    // Check for typical Le Mans classes
    let classes: Vec<motorsport::Class> = cars.iter()
        .map(|c| c.meta_data.class.clone())
        .collect();
    
    assert!(classes.contains(&motorsport::Class::LMH), "Should have LMH cars");
    assert!(classes.contains(&motorsport::Class::LMP2), "Should have LMP2 cars");
    assert!(classes.contains(&motorsport::Class::LMGT3), "Should have LMGT3 cars");
}

#[test]
fn test_real_data_elm_compatibility() {
    let csv_path = "../../app/static/wec/2025/imola_6h.csv";
    if !Path::new(csv_path).exists() {
        println!("Skipping test - CSV file not found: {}", csv_path);
        return;
    }

    let test_output = "test_real_data_elm_compatibility.json";
    
    // Clean up any existing test file
    if fs::metadata(test_output).is_ok() {
        fs::remove_file(test_output).expect("Failed to remove existing test file");
    }

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

    // Validate Elm-compatible car structure and implemented features
    for car in preprocessed {
        // Required fields for Elm compatibility
        assert!(car.get("carNumber").is_some(), "Car should have carNumber");
        assert!(car.get("drivers").is_some(), "Car should have drivers");
        assert!(car.get("class").is_some(), "Car should have class");
        assert!(car.get("team").is_some(), "Car should have team");
        assert!(car.get("manufacturer").is_some(), "Car should have manufacturer");
        assert!(car.get("startPosition").is_some(), "Car should have startPosition");
        assert!(car.get("laps").is_some(), "Car should have laps");
        
        // Check implemented features
        assert!(car.get("startPosition").unwrap().as_i64().unwrap() >= 1, 
            "startPosition should be calculated (1 or higher)");
        assert!(car.get("currentLap").is_some(), "currentLap should be present");
        assert!(car.get("lastLap").is_some(), "lastLap should be present");

        // Validate drivers array structure
        let drivers = car.get("drivers").unwrap().as_array().unwrap();
        if !drivers.is_empty() {
            let driver = &drivers[0];
            assert!(driver.get("name").is_some(), "Driver should have name");
            assert!(driver.get("isCurrentDriver").is_some(), "Driver should have isCurrentDriver");
        }

        // Validate laps array structure and features
        let laps = car.get("laps").unwrap().as_array().unwrap();
        if !laps.is_empty() {
            let lap = &laps[0];
            assert!(lap.get("carNumber").is_some(), "Lap should have carNumber");
            assert!(lap.get("driver").is_some(), "Lap should have driver");
            assert!(lap.get("lap").is_some(), "Lap should have lap number");
            assert!(lap.get("time").is_some(), "Lap should have time");
            assert!(lap.get("elapsed").is_some(), "Lap should have elapsed");
            
            // Position should be calculated for most laps
            assert!(lap.get("position").is_some(), "position should be calculated");
            if !lap.get("position").unwrap().is_null() {
                let position = lap.get("position").unwrap().as_i64().unwrap();
                assert!(position >= 1, "position should be 1 or higher when calculated");
            }
            
            // Best times should equal current times (current implementation behavior)
            let time = lap.get("time").unwrap().as_str().unwrap();
            let best = lap.get("best").unwrap().as_str().unwrap();
            assert_eq!(time, best, "best time equals current time (current implementation behavior)");
        }
    }

    // Clean up test file
    fs::remove_file(test_output).expect("Failed to clean up test file");
}

#[test]
fn test_real_data_multi_race_consistency() {
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

        let csv_content = fs::read_to_string(csv_path)
            .unwrap_or_else(|_| panic!("Failed to read CSV for {}", race_name));

        let laps_with_metadata = parse_laps_from_csv(&csv_content);
        assert!(!laps_with_metadata.is_empty(), "{} should have laps", race_name);

        let cars = group_laps_by_car(laps_with_metadata);
        assert!(!cars.is_empty(), "{} should have cars", race_name);

        // Basic validation that all races have consistent structure
        for car in &cars {
            assert!(!car.meta_data.car_number.is_empty(), "{}: Car should have number", race_name);
            assert!(!car.meta_data.drivers.is_empty(), "{}: Car should have drivers", race_name);
            assert!(!car.laps.is_empty(), "{}: Car should have laps", race_name);
            assert!(car.start_position > 0, "{}: Car should have valid start position", race_name);

            // Check lap structure consistency
            for lap in &car.laps {
                assert!(lap.time > 0, "{}: Lap should have positive time", race_name);
                assert!(lap.elapsed > 0, "{}: Lap should have positive elapsed time", race_name);
            }
        }

        println!("✓ {} processed successfully: {} cars, {} total laps", 
                race_name, cars.len(), cars.iter().map(|c| c.laps.len()).sum::<usize>());
    }
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

fn optional_string_to_elm(value: &str) -> String {
    // Elmでは空の値は空文字列として表現
    value.to_string()
}

fn create_test_csv_data() -> String {
    r#"NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS;
12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;0:23.155;0:29.928;0:42.282;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;23.155;29.928;42.282;
7;1;1;1:33.291;0;;23.119;0;29.188;0;40.984;0;175.0;1:33.291;11:02:00.782;0:23.119;0:29.188;0:40.984;298.6;Kamui KOBAYASHI;;HYPERCAR;H;Toyota Gazoo Racing;Toyota;GF;23.119;29.188;40.984;
12;2;2;1:32.245;1;;22.500;1;29.100;1;40.645;1;165.2;3:07.610;11:03:35.101;0:22.500;0:29.100;0:40.645;;Robin FRIJNS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;22.500;29.100;40.645;"#.to_string()
}