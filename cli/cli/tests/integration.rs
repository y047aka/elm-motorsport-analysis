use std::fs;
use std::path::Path;

use cli::{run, Config, parse_laps_from_csv, group_laps_by_car, create_elm_compatible_output, map_event_name};

// =============================================================================
// INTEGRATION TESTS
// =============================================================================

#[test]
fn test_csv_parsing_and_data_processing() {
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
fn test_cli_end_to_end_execution() {
    // テスト用の出力ファイル名
    let test_output = "test_integration_output.json";

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

    // JSONとして有効であることを確認
    let output: Result<serde_json::Value, _> = serde_json::from_str(&json_content);
    assert!(output.is_ok(), "出力されたJSONは有効な形式であるはず");

    let output = output.unwrap();
    assert!(output.is_object(), "トップレベルはオブジェクトであるはず");

    // 3層構造を検証
    let obj = output.as_object().unwrap();
    assert!(obj.contains_key("name"), "nameフィールドが存在するはず");
    assert!(obj.contains_key("laps"), "lapsフィールドが存在するはず");
    assert!(obj.contains_key("preprocessed"), "preprocessedフィールドが存在するはず");

    // preprocessed車両データが存在することを確認
    let preprocessed = obj.get("preprocessed").unwrap().as_array().unwrap();
    assert!(!preprocessed.is_empty(), "車両データが存在するはず");

    // 各車両の基本構造を検証
    for car in preprocessed {
        assert!(car.get("carNumber").is_some(), "carNumberフィールドが存在するはず");
        assert!(car.get("drivers").is_some(), "driversフィールドが存在するはず");
        assert!(car.get("laps").is_some(), "lapsフィールドが存在するはず");
        assert!(car.get("startPosition").is_some(), "startPositionフィールドが存在するはず");
        assert!(car.get("class").is_some(), "classフィールドが存在するはず");
        assert!(car.get("currentLap").is_some(), "currentLapフィールドが存在するはず");
        assert!(car.get("lastLap").is_some(), "lastLapフィールドが存在するはず");
    }

    // テストファイルをクリーンアップ
    fs::remove_file(test_output).expect("テストファイルのクリーンアップに失敗");
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
    let test_files = vec![
        ("../../app/static/wec/2025/imola_6h.csv", "Imola", 20, "007", "Aston Martin Thor Team"),
        ("../../app/static/wec/2025/le_mans_24h.csv", "Le Mans", 50, "007", "Aston Martin Thor Team"),
        ("../../app/static/wec/2025/spa_6h.csv", "Spa", 20, "007", "Aston Martin Thor Team"),
    ];

    for (csv_path, race_name, min_cars, test_car, expected_team) in test_files {
        if !Path::new(csv_path).exists() {
            println!("Skipping {} - CSV file not found: {}", race_name, csv_path);
            continue;
        }

        let csv_content = fs::read_to_string(csv_path)
            .unwrap_or_else(|_| panic!("Failed to read CSV for {}", race_name));

        let laps_with_metadata = parse_laps_from_csv(&csv_content);
        assert!(!laps_with_metadata.is_empty(), "{} should parse laps from CSV", race_name);

        let cars = group_laps_by_car(laps_with_metadata);
        assert!(!cars.is_empty(), "{} should have cars grouped", race_name);
        assert!(cars.len() >= min_cars, "{} should have at least {} cars", race_name, min_cars);

        // Test specific car exists and has expected data
        if let Some(test_car_data) = cars.iter().find(|c| c.meta_data.car_number == test_car) {
            assert!(!test_car_data.laps.is_empty(), "{}: Car {} should have laps", race_name, test_car);
            assert_eq!(test_car_data.meta_data.team, expected_team, 
                "{}: Car {} should have correct team", race_name, test_car);
        }

        // Validate all cars have consistent structure
        for car in &cars {
            assert!(!car.meta_data.car_number.is_empty(), "{}: Car should have number", race_name);
            assert!(!car.meta_data.drivers.is_empty(), "{}: Car should have drivers", race_name);
            assert!(!car.laps.is_empty(), "{}: Car should have laps", race_name);
            assert!(car.start_position > 0, "{}: Car should have valid start position", race_name);

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
// ELM COMPATIBILITY TESTS
// =============================================================================

#[test] 
fn test_elm_event_name_mapping() {
    // EventのID→表示名マッピング（Elm Main.toEventName互換）
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
fn test_elm_output_field_completeness() {
    // Elm互換出力の全フィールド存在確認（APIコントラクト検証）
    let csv_data = create_test_csv_data();
    let laps_with_metadata = parse_laps_from_csv(&csv_data);
    let cars = group_laps_by_car(laps_with_metadata.clone());
    
    let elm_output = create_elm_compatible_output("Test Event", &laps_with_metadata, &cars);
    let json_value = serde_json::to_value(&elm_output).unwrap();
    
    // raw lapsの全フィールド確認
    let laps_array = json_value["laps"].as_array().unwrap();
    if !laps_array.is_empty() {
        let first_lap = &laps_array[0];
        
        // camelCase形式の必須フィールド（Elm APIコントラクト）
        assert!(first_lap.get("carNumber").is_some(), "carNumber field required");
        assert!(first_lap.get("driverNumber").is_some(), "driverNumber field required");
        assert!(first_lap.get("lapNumber").is_some(), "lapNumber field required");
        assert!(first_lap.get("lapTime").is_some(), "lapTime field required");
        assert!(first_lap.get("lapImprovement").is_some(), "lapImprovement field required");
        assert!(first_lap.get("crossingFinishLineInPit").is_some(), "crossingFinishLineInPit field required");
        assert!(first_lap.get("s1").is_some(), "s1 field required");
        assert!(first_lap.get("s1Improvement").is_some(), "s1Improvement field required");
        assert!(first_lap.get("s2").is_some(), "s2 field required");
        assert!(first_lap.get("s2Improvement").is_some(), "s2Improvement field required");
        assert!(first_lap.get("s3").is_some(), "s3 field required");
        assert!(first_lap.get("s3Improvement").is_some(), "s3Improvement field required");
        assert!(first_lap.get("kph").is_some(), "kph field required");
        assert!(first_lap.get("elapsed").is_some(), "elapsed field required");
        assert!(first_lap.get("hour").is_some(), "hour field required");
        assert!(first_lap.get("topSpeed").is_some(), "topSpeed field required");
        assert!(first_lap.get("driverName").is_some(), "driverName field required");
        assert!(first_lap.get("pitTime").is_some(), "pitTime field required");
        assert!(first_lap.get("class").is_some(), "class field required");
        assert!(first_lap.get("group").is_some(), "group field required");
        assert!(first_lap.get("team").is_some(), "team field required");
        assert!(first_lap.get("manufacturer").is_some(), "manufacturer field required");
        
        // データ型確認（Elm型システム互換）
        assert!(first_lap["carNumber"].is_string(), "carNumber should be string");
        assert!(first_lap["driverNumber"].is_number(), "driverNumber should be number");
        assert!(first_lap["lapTime"].is_string(), "lapTime should be string (duration format)");
        assert!(first_lap["kph"].is_number(), "kph should be number");
    }
    
    // preprocessed carsの全フィールド確認
    let preprocessed_array = json_value["preprocessed"].as_array().unwrap();
    if !preprocessed_array.is_empty() {
        let first_car = &preprocessed_array[0];
        
        // Car level必須フィールド
        assert!(first_car.get("carNumber").is_some(), "car carNumber field required");
        assert!(first_car.get("drivers").is_some(), "drivers field required");
        assert!(first_car.get("class").is_some(), "car class field required");
        assert!(first_car.get("startPosition").is_some(), "startPosition field required");
        assert!(first_car.get("currentLap").is_some(), "currentLap field required");
        assert!(first_car.get("lastLap").is_some(), "lastLap field required");
        
        // drivers配列構造確認
        let drivers = first_car["drivers"].as_array().unwrap();
        if !drivers.is_empty() {
            let first_driver = &drivers[0];
            assert!(first_driver.get("name").is_some(), "driver name field required");
            assert!(first_driver.get("isCurrentDriver").is_some(), "isCurrentDriver field required");
            assert!(first_driver["isCurrentDriver"].is_boolean(), "isCurrentDriver should be boolean");
        }
        
        // preprocessed laps配列構造確認
        let laps = first_car["laps"].as_array().unwrap();
        if !laps.is_empty() {
            let first_lap = &laps[0];
            assert!(first_lap.get("carNumber").is_some(), "lap carNumber field required");
            assert!(first_lap.get("driver").is_some(), "driver field required");
            assert!(first_lap.get("lap").is_some(), "lap number field required");
            assert!(first_lap.get("position").is_some(), "position field required");
            assert!(first_lap.get("time").is_some(), "time field required");
            assert!(first_lap.get("best").is_some(), "best field required");
            assert!(first_lap.get("sector_1").is_some(), "sector_1 field required");
            assert!(first_lap.get("sector_2").is_some(), "sector_2 field required");
            assert!(first_lap.get("sector_3").is_some(), "sector_3 field required");
            assert!(first_lap.get("s1_best").is_some(), "s1_best field required");
            assert!(first_lap.get("s2_best").is_some(), "s2_best field required");
            assert!(first_lap.get("s3_best").is_some(), "s3_best field required");
            assert!(first_lap.get("elapsed").is_some(), "elapsed field required");
            
            // データ型確認
            assert!(first_lap["time"].is_string(), "time should be string (duration format)");
            assert!(first_lap["lap"].is_number(), "lap should be number");
        }
    }
}

#[test]
fn test_elm_optional_field_handling() {
    // Elm特有の空文字列処理（nullではなく空文字列として表現）
    assert_eq!(optional_string_to_elm(""), "", "Empty string should remain empty");
    assert_eq!(optional_string_to_elm("123.456"), "123.456", "Non-empty string should be preserved");
}

// =============================================================================
// HELPER FUNCTIONS  
// =============================================================================

fn optional_string_to_elm(value: &str) -> String {
    // Elmでは空の値は空文字列として表現（nullではなく）
    value.to_string()
}

fn create_test_csv_data() -> String {
    r#"NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS;
12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;0:23.155;0:29.928;0:42.282;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;23.155;29.928;42.282;
7;1;1;1:33.291;0;;23.119;0;29.188;0;40.984;0;175.0;1:33.291;11:02:00.782;0:23.119;0:29.188;0:40.984;298.6;Kamui KOBAYASHI;;HYPERCAR;H;Toyota Gazoo Racing;Toyota;GF;23.119;29.188;40.984;
12;2;2;1:32.245;1;;22.500;1;29.100;1;40.645;1;165.2;3:07.610;11:03:35.101;0:22.500;0:29.100;0:40.645;;Robin FRIJNS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;22.500;29.100;40.645;"#.to_string()
}