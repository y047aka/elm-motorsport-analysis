use std::fs;

use motorsport::{group_laps_by_car, parse_laps_from_csv};

#[test]
fn test_integration_csv_to_cars() {
    // テスト用CSVファイルを読み込む
    let csv_path = "../test_data.csv";
    let csv_content = fs::read_to_string(csv_path).expect("CSVファイルの読み込みに失敗");

    // Lapリストにパース
    let laps = parse_laps_from_csv(&csv_content);

    // Carごとにグループ化
    let cars = group_laps_by_car(laps);

    // 実際のテストデータに基づいたassert
    assert!(!cars.is_empty(), "少なくとも1台の車両が存在するはず");

    // 各車両にラップデータが存在することを確認
    for car in &cars {
        assert!(!car.laps.is_empty(), "各車両にはラップデータが存在するはず");
    }
}
