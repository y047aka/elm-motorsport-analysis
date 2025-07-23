use std::fs;

use cli::{run, Config};
use cli::preprocess::{parse_laps_from_csv, group_laps_by_car};

#[test]
fn test_integration_csv_to_json_full_flow() {
    // テスト用CSVファイルを読み込む
    let csv_path = "../test_data.csv";
    let csv_content = fs::read_to_string(csv_path).expect("CSVファイルの読み込みに失敗");

    // CSVからLapリストにパース
    let laps = parse_laps_from_csv(&csv_content);
    assert!(!laps.is_empty(), "CSVから少なくとも1つのラップが解析されるはず");

    // 最初のラップの内容を検証
    let first_lap = &laps[0];
    assert_eq!(first_lap.car_number, "12");
    assert_eq!(first_lap.driver, "Will STEVENS");
    assert_eq!(first_lap.lap, 1);
    assert!(first_lap.time > 0, "ラップタイムは0より大きいはず");
    assert!(first_lap.elapsed > 0, "経過時間は0より大きいはず");

    // Carごとにグループ化
    let cars = group_laps_by_car(laps);
    assert!(!cars.is_empty(), "少なくとも1台の車両が存在するはず");

    // 各車両にラップデータが存在することを確認
    for car in &cars {
        assert!(!car.laps.is_empty(), "各車両にはラップデータが存在するはず");
        assert!(!car.meta_data.car_number.is_empty(), "車両番号は存在するはず");
        assert!(!car.meta_data.drivers.is_empty(), "ドライバー情報は存在するはず");
    }

    // 特定の車両の詳細検証
    let car12 = cars.iter().find(|c| c.meta_data.car_number == "12");
    assert!(car12.is_some(), "車両12が存在するはず");

    let car12 = car12.unwrap();
    assert!(car12.laps.len() >= 1, "車両12には少なくとも1つのラップが存在するはず");

    // ラップデータの整合性チェック
    for lap in &car12.laps {
        assert_eq!(lap.car_number, "12");
        assert!(lap.time > 0, "ラップタイムは正の値であるはず");
        assert!(lap.sector_1 > 0, "セクター1は正の値であるはず");
        assert!(lap.sector_2 > 0, "セクター2は正の値であるはず");
        assert!(lap.sector_3 > 0, "セクター3は正の値であるはず");
    }
}

#[test]
fn test_integration_cli_run_command() {
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
    let cars: Result<Vec<serde_json::Value>, _> = serde_json::from_str(&json_content);
    assert!(cars.is_ok(), "出力されたJSONは有効な形式であるはず");

    let cars = cars.unwrap();
    assert!(!cars.is_empty(), "車両データが存在するはず");

    // 各車両の基本構造を検証
    for car in &cars {
        assert!(car.get("meta_data").is_some(), "meta_dataフィールドが存在するはず");
        assert!(car.get("laps").is_some(), "lapsフィールドが存在するはず");
        assert!(car.get("start_position").is_some(), "start_positionフィールドが存在するはず");
        assert!(car.get("status").is_some(), "statusフィールドが存在するはず");

        let meta_data = car.get("meta_data").unwrap();
        assert!(meta_data.get("car_number").is_some(), "car_numberフィールドが存在するはず");
        assert!(meta_data.get("drivers").is_some(), "driversフィールドが存在するはず");
        assert!(meta_data.get("class").is_some(), "classフィールドが存在するはず");
    }

    // テストファイルをクリーンアップ
    fs::remove_file(test_output).expect("テストファイルのクリーンアップに失敗");
}

#[test]
fn test_integration_csv_parsing_edge_cases() {
    // 空のCSVデータのテスト
    let empty_csv = "NUMBER;DRIVER_NAME;LAP_NUMBER;LAP_TIME;S1;S2;S3;ELAPSED\n";
    let laps = parse_laps_from_csv(empty_csv);
    assert_eq!(laps.len(), 0, "空のCSVからは0個のラップが解析されるはず");

    // 不正なデータを含むCSVのテスト（エラーハンドリング確認）
    let invalid_csv = "NUMBER;DRIVER_NAME;LAP_NUMBER;LAP_TIME;S1;S2;S3;ELAPSED\n12;Will STEVENS;1;invalid_time;23.155;29.928;42.282;1:35.365\n";
    let laps = parse_laps_from_csv(invalid_csv);
    // 不正なデータは0に変換されるが、ラップ自体は作成される
    assert_eq!(laps.len(), 1, "不正なタイムを含む行も処理されるはず");
    assert_eq!(laps[0].time, 0, "不正なタイムは0に変換されるはず");

    // 単一ラップのCSVテスト
    let single_lap_csv = "NUMBER;DRIVER_NAME;LAP_NUMBER;LAP_TIME;S1;S2;S3;ELAPSED\n7;Kamui KOBAYASHI;1;1:33.291;23.119;29.188;40.984;1:33.291\n";
    let laps = parse_laps_from_csv(single_lap_csv);
    assert_eq!(laps.len(), 1, "単一ラップが正しく解析されるはず");
    assert_eq!(laps[0].car_number, "7");
    assert_eq!(laps[0].driver, "Kamui KOBAYASHI");
    assert_eq!(laps[0].lap, 1);
    assert_eq!(laps[0].time, 93291); // 1:33.291 = 93291ms
}

#[test]
fn test_integration_car_grouping_logic() {
    // 複数ドライバー、複数車両のテストデータ
    let multi_driver_csv = r#"NUMBER;DRIVER_NAME;LAP_NUMBER;LAP_TIME;S1;S2;S3;ELAPSED
12;Will STEVENS;1;1:35.365;23.155;29.928;42.282;1:35.365
12;Robin FRIJNS;2;1:33.610;26.770;29.296;37.544;3:08.975
7;Kamui KOBAYASHI;1;1:33.291;23.119;29.188;40.984;1:33.291
7;Jose Maria LOPEZ;2;1:34.121;23.277;29.848;40.996;3:07.412
8;Sebastien BOURDAIS;1;1:36.500;24.000;30.500;42.000;1:36.500"#;

    let laps = parse_laps_from_csv(multi_driver_csv);
    assert_eq!(laps.len(), 5, "5つのラップが解析されるはず");

    let cars = group_laps_by_car(laps);
    assert_eq!(cars.len(), 3, "3台の車両にグループ化されるはず");

    // 車両12の検証（2ラップ、異なるドライバー）
    let car12 = cars.iter().find(|c| c.meta_data.car_number == "12").unwrap();
    assert_eq!(car12.laps.len(), 2, "車両12には2つのラップがあるはず");

    let drivers_in_car12: std::collections::HashSet<&str> = car12.laps.iter()
        .map(|lap| lap.driver.as_str())
        .collect();
    assert_eq!(drivers_in_car12.len(), 2, "車両12には2人のドライバーがいるはず");
    assert!(drivers_in_car12.contains("Will STEVENS"));
    assert!(drivers_in_car12.contains("Robin FRIJNS"));

    // 車両7の検証（2ラップ、異なるドライバー）
    let car7 = cars.iter().find(|c| c.meta_data.car_number == "7").unwrap();
    assert_eq!(car7.laps.len(), 2, "車両7には2つのラップがあるはず");

    // 車両8の検証（1ラップ、単一ドライバー）
    let car8 = cars.iter().find(|c| c.meta_data.car_number == "8").unwrap();
    assert_eq!(car8.laps.len(), 1, "車両8には1つのラップがあるはず");
    assert_eq!(car8.laps[0].driver, "Sebastien BOURDAIS");
}
