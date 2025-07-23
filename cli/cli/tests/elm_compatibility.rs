use cli::{parse_laps_from_csv, group_laps_by_car};
use cli::preprocess::LapWithMetadata;
use serde_json::{Value, json};

/// Elm互換の3層出力構造をテストする
#[test]
fn test_elm_compatible_output_structure() {
    let csv_data = create_test_csv_data();
    let laps_with_metadata = parse_laps_from_csv(&csv_data);
    let cars = group_laps_by_car(laps_with_metadata.clone());
    
    // Elm互換のJSON構造を作成する関数をテスト
    let elm_output = create_elm_compatible_output("Qatar 1812km", &laps_with_metadata, &cars);
    
    // トップレベル構造の確認
    assert!(elm_output.is_object());
    let obj = elm_output.as_object().unwrap();
    
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

/// Raw lap data format（laps配列）の構造をテストする
#[test]
fn test_elm_raw_lap_format() {
    let csv_data = create_test_csv_data();
    let laps_with_metadata = parse_laps_from_csv(&csv_data);
    let cars = group_laps_by_car(laps_with_metadata.clone());
    
    let elm_output = create_elm_compatible_output("Test Event", &laps_with_metadata, &cars);
    let laps_array = elm_output["laps"].as_array().unwrap();
    
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

/// Preprocessed car data format（preprocessed配列）の構造をテストする
#[test]
fn test_elm_preprocessed_car_format() {
    let csv_data = create_test_csv_data();
    let laps_with_metadata = parse_laps_from_csv(&csv_data);
    let cars = group_laps_by_car(laps_with_metadata.clone());
    
    let elm_output = create_elm_compatible_output("Test Event", &laps_with_metadata, &cars);
    let preprocessed_array = elm_output["preprocessed"].as_array().unwrap();
    
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

/// Duration format（Elm互換）をテストする
#[test]
fn test_elm_duration_format() {
    // Elmの Duration.toString 形式のテスト
    assert_eq!(format_duration_elm_style(0), "0.000");
    assert_eq!(format_duration_elm_style(4321), "4.321");
    assert_eq!(format_duration_elm_style(28076), "28.076");
    assert_eq!(format_duration_elm_style(414321), "6:54.321");
    assert_eq!(format_duration_elm_style(25614321), "7:06:54.321");
}

/// Event name mappingをテストする
#[test]
fn test_event_name_mapping() {
    assert_eq!(map_event_name("qatar_1812km"), "Qatar 1812km");
    assert_eq!(map_event_name("imola_6h"), "6 Hours of Imola");
    assert_eq!(map_event_name("spa_6h"), "6 Hours of Spa");
    assert_eq!(map_event_name("le_mans_24h"), "24 Hours of Le Mans");
    assert_eq!(map_event_name("fuji_6h"), "6 Hours of Fuji");
    assert_eq!(map_event_name("bahrain_8h"), "8 Hours of Bahrain");
    assert_eq!(map_event_name("sao_paulo_6h"), "6 Hours of São Paulo");
    assert_eq!(map_event_name("unknown_event"), "Encoding Error");
}

/// Optional fieldsの空文字列処理をテストする
#[test]
fn test_optional_field_handling() {
    // Elmでは空のdurationやtop_speedは空文字列（nullではない）
    assert_eq!(optional_string_to_elm(""), "");
    assert_eq!(optional_string_to_elm("123.456"), "123.456");
}

// ===== Helper functions (実装予定) =====

fn create_elm_compatible_output(
    event_name: &str,
    laps_with_metadata: &[LapWithMetadata],
    cars: &[motorsport::Car],
) -> Value {
    // この関数は実装が必要
    // テストファーストのため、まず期待する構造を返すダミーを作成
    json!({
        "name": event_name,
        "laps": [],
        "preprocessed": []
    })
}

fn format_duration_elm_style(_milliseconds: u32) -> String {
    // Elm Duration.toString の実装が必要
    // テストファーストのため、まず失敗させる
    "0.000".to_string()
}

fn map_event_name(event_id: &str) -> String {
    // Elm Main.toEventName の実装が必要
    match event_id {
        "qatar_1812km" => "Qatar 1812km".to_string(),
        "imola_6h" => "6 Hours of Imola".to_string(),
        "spa_6h" => "6 Hours of Spa".to_string(),
        "le_mans_24h" => "24 Hours of Le Mans".to_string(),
        "fuji_6h" => "6 Hours of Fuji".to_string(),
        "bahrain_8h" => "8 Hours of Bahrain".to_string(),
        "sao_paulo_6h" => "6 Hours of São Paulo".to_string(),
        _ => "Encoding Error".to_string(),
    }
}

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