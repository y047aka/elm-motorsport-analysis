use std::fs;

use motorsport::{group_laps_by_car, Lap};

#[test]
fn test_integration_csv_to_cars() {
    // テスト用CSVファイルを読み込む
    let csv_path = "../test_data.csv";
    let csv_content = fs::read_to_string(csv_path).expect("CSVファイルの読み込みに失敗");

    // Lapリストにパース（現状は空でもOK）
    let laps: Vec<Lap> = vec![]; // TODO: parse_laps_from_csv(&csv_content)

    // Carごとにグループ化
    let cars = group_laps_by_car(laps);

    // 期待される車両数やラップ数をassert（仮）
    // assert_eq!(cars.len(), 2);
    // let car12 = cars.iter().find(|c| c.meta_data.car_number == "12").unwrap();
    // assert_eq!(car12.laps.len(), 10);
    // ...
}
