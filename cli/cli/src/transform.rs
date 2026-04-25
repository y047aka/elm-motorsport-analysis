//! ステージ2: `LapWithMetadata` のリストを車両ごとの [`Car`] に集約する。
//!
//! - 車両単位でのグルーピング
//! - ラップ走行中のベストタイム（ラップ/S1/S2/S3/ミニセクター）の累積更新
//! - 各ラップの順位計算
//!
//! 型の整理は後続のステップで行うため、ここでは現状のロジックを保ったまま移設している。

use std::collections::HashMap;

use motorsport::{Car, Class, Driver, Lap, MetaData, MiniSector, MiniSectors, duration};

use crate::csv_input::{ExtraData, LapWithMetadata, Metadata, normalize_cell};

/// ミニセクターのベストタイム追跡用構造体
#[derive(Debug, Clone)]
struct MiniSectorBests {
    pub best_scl2: Option<u32>,
    pub best_z4: Option<u32>,
    pub best_ip1: Option<u32>,
    pub best_z12: Option<u32>,
    pub best_sclc: Option<u32>,
    pub best_a7_1: Option<u32>,
    pub best_ip2: Option<u32>,
    pub best_a8_1: Option<u32>,
    pub best_sclb: Option<u32>,
    pub best_porin: Option<u32>,
    pub best_porout: Option<u32>,
    pub best_pitref: Option<u32>,
    pub best_scl1: Option<u32>,
    pub best_fordout: Option<u32>,
    pub best_fl: Option<u32>,
}

impl MiniSectorBests {
    fn new() -> Self {
        MiniSectorBests {
            best_scl2: None,
            best_z4: None,
            best_ip1: None,
            best_z12: None,
            best_sclc: None,
            best_a7_1: None,
            best_ip2: None,
            best_a8_1: None,
            best_sclb: None,
            best_porin: None,
            best_porout: None,
            best_pitref: None,
            best_scl1: None,
            best_fordout: None,
            best_fl: None,
        }
    }

    /// ベストタイムを更新（0でない場合のみ）
    fn update_best(best: Option<u32>, current: u32) -> Option<u32> {
        if current > 0 {
            Some(best.map_or(current, |b| b.min(current)))
        } else {
            best
        }
    }

    /// 指定されたミニセクターのベストタイムを更新
    fn update_from_raw(&mut self, extra_data: &ExtraData) {
        let parse_duration =
            |opt_str: &Option<String>| opt_str.as_ref().and_then(|s| duration::from_string(s));

        if let Some(time) = parse_duration(&extra_data.scl2_time) {
            self.best_scl2 = Self::update_best(self.best_scl2, time);
        }
        if let Some(time) = parse_duration(&extra_data.z4_time) {
            self.best_z4 = Self::update_best(self.best_z4, time);
        }
        if let Some(time) = parse_duration(&extra_data.ip1_time) {
            self.best_ip1 = Self::update_best(self.best_ip1, time);
        }
        if let Some(time) = parse_duration(&extra_data.z12_time) {
            self.best_z12 = Self::update_best(self.best_z12, time);
        }
        if let Some(time) = parse_duration(&extra_data.sclc_time) {
            self.best_sclc = Self::update_best(self.best_sclc, time);
        }
        if let Some(time) = parse_duration(&extra_data.a7_1_time) {
            self.best_a7_1 = Self::update_best(self.best_a7_1, time);
        }
        if let Some(time) = parse_duration(&extra_data.ip2_time) {
            self.best_ip2 = Self::update_best(self.best_ip2, time);
        }
        if let Some(time) = parse_duration(&extra_data.a8_1_time) {
            self.best_a8_1 = Self::update_best(self.best_a8_1, time);
        }
        if let Some(time) = parse_duration(&extra_data.sclb_time) {
            self.best_sclb = Self::update_best(self.best_sclb, time);
        }
        if let Some(time) = parse_duration(&extra_data.porin_time) {
            self.best_porin = Self::update_best(self.best_porin, time);
        }
        if let Some(time) = parse_duration(&extra_data.porout_time) {
            self.best_porout = Self::update_best(self.best_porout, time);
        }
        if let Some(time) = parse_duration(&extra_data.pitref_time) {
            self.best_pitref = Self::update_best(self.best_pitref, time);
        }
        if let Some(time) = parse_duration(&extra_data.scl1_time) {
            self.best_scl1 = Self::update_best(self.best_scl1, time);
        }
        if let Some(time) = parse_duration(&extra_data.fordout_time) {
            self.best_fordout = Self::update_best(self.best_fordout, time);
        }
        if let Some(time) = parse_duration(&extra_data.fl_time) {
            self.best_fl = Self::update_best(self.best_fl, time);
        }
    }
}

/// ExtraDataからMiniSectors構造体を作成（ベストタイム付き）
fn build_mini_sectors_with_bests(
    extra_data: &ExtraData,
    bests: &MiniSectorBests,
) -> Option<MiniSectors> {
    // いずれかの値が存在すればミニセクターありとみなす
    let any_present = [
        &extra_data.scl2_time,
        &extra_data.scl2_elapsed,
        &extra_data.z4_time,
        &extra_data.z4_elapsed,
        &extra_data.ip1_time,
        &extra_data.ip1_elapsed,
        &extra_data.z12_time,
        &extra_data.z12_elapsed,
        &extra_data.sclc_time,
        &extra_data.sclc_elapsed,
        &extra_data.a7_1_time,
        &extra_data.a7_1_elapsed,
        &extra_data.ip2_time,
        &extra_data.ip2_elapsed,
        &extra_data.a8_1_time,
        &extra_data.a8_1_elapsed,
        &extra_data.sclb_time,
        &extra_data.sclb_elapsed,
        &extra_data.porin_time,
        &extra_data.porin_elapsed,
        &extra_data.porout_time,
        &extra_data.porout_elapsed,
        &extra_data.pitref_time,
        &extra_data.pitref_elapsed,
        &extra_data.scl1_time,
        &extra_data.scl1_elapsed,
        &extra_data.fordout_time,
        &extra_data.fordout_elapsed,
        &extra_data.fl_time,
        &extra_data.fl_elapsed,
    ]
    .iter()
    .any(|v| normalize_cell(v).is_some());

    if !any_present {
        return None;
    }

    let parse_duration = |opt_str: &Option<String>| {
        opt_str
            .as_ref()
            .and_then(|s| duration::from_string(s))
            .unwrap_or(0)
    };

    let parse_elapsed = |opt_str: &Option<String>| {
        opt_str
            .as_ref()
            .and_then(|s| duration::from_string(s))
            .unwrap_or(0)
    };

    let mk_minisector = |time_opt: &Option<String>,
                         elapsed_opt: &Option<String>,
                         best_opt: Option<u32>| MiniSector {
        time: parse_duration(time_opt),
        elapsed: parse_elapsed(elapsed_opt),
        best: best_opt.unwrap_or(0),
    };

    Some(MiniSectors {
        scl2: mk_minisector(
            &extra_data.scl2_time,
            &extra_data.scl2_elapsed,
            bests.best_scl2,
        ),
        z4: mk_minisector(&extra_data.z4_time, &extra_data.z4_elapsed, bests.best_z4),
        ip1: mk_minisector(
            &extra_data.ip1_time,
            &extra_data.ip1_elapsed,
            bests.best_ip1,
        ),
        z12: mk_minisector(
            &extra_data.z12_time,
            &extra_data.z12_elapsed,
            bests.best_z12,
        ),
        sclc: mk_minisector(
            &extra_data.sclc_time,
            &extra_data.sclc_elapsed,
            bests.best_sclc,
        ),
        a7_1: mk_minisector(
            &extra_data.a7_1_time,
            &extra_data.a7_1_elapsed,
            bests.best_a7_1,
        ),
        ip2: mk_minisector(
            &extra_data.ip2_time,
            &extra_data.ip2_elapsed,
            bests.best_ip2,
        ),
        a8_1: mk_minisector(
            &extra_data.a8_1_time,
            &extra_data.a8_1_elapsed,
            bests.best_a8_1,
        ),
        sclb: mk_minisector(
            &extra_data.sclb_time,
            &extra_data.sclb_elapsed,
            bests.best_sclb,
        ),
        porin: mk_minisector(
            &extra_data.porin_time,
            &extra_data.porin_elapsed,
            bests.best_porin,
        ),
        porout: mk_minisector(
            &extra_data.porout_time,
            &extra_data.porout_elapsed,
            bests.best_porout,
        ),
        pitref: mk_minisector(
            &extra_data.pitref_time,
            &extra_data.pitref_elapsed,
            bests.best_pitref,
        ),
        scl1: mk_minisector(
            &extra_data.scl1_time,
            &extra_data.scl1_elapsed,
            bests.best_scl1,
        ),
        fordout: mk_minisector(
            &extra_data.fordout_time,
            &extra_data.fordout_elapsed,
            bests.best_fordout,
        ),
        fl: mk_minisector(&extra_data.fl_time, &extra_data.fl_elapsed, bests.best_fl),
    })
}

/// LapWithMetadataリストをCarごとにグループ化する
pub fn group_laps_by_car(laps_with_metadata: Vec<LapWithMetadata>) -> Vec<Car> {
    // インデックス付きグループ化でCSV出現順序を保持
    let mut car_data: HashMap<String, (Vec<LapWithMetadata>, Vec<String>, usize)> = HashMap::new();

    for (index, lap_with_meta) in laps_with_metadata.into_iter().enumerate() {
        let car_number = lap_with_meta.lap.car_number.clone();
        let driver_name = lap_with_meta.lap.driver.clone();

        // 車両データを蓄積
        car_data
            .entry(car_number)
            .and_modify(|(laps, drivers, _)| {
                laps.push(lap_with_meta.clone());
                if !drivers.contains(&driver_name) {
                    drivers.push(driver_name.clone());
                }
            })
            .or_insert((
                vec![lap_with_meta],
                vec![driver_name],
                index, // 最初の出現インデックスを保存
            ));
    }

    // 車両を作成し、最初の出現順序でソート
    let mut cars_with_index: Vec<(usize, Car)> = car_data
        .into_iter()
        .map(
            |(car_number, (laps_with_metadata, driver_names, first_index))| {
                let car = car_from_grouped_data(car_number, laps_with_metadata, driver_names);
                (first_index, car)
            },
        )
        .collect();

    // CSVの出現順序でソート
    cars_with_index.sort_by_key(|(index, _)| *index);

    let mut cars: Vec<Car> = cars_with_index.into_iter().map(|(_, car)| car).collect();

    // 位置計算を実行
    calculate_positions(&mut cars);

    cars
}

/// グループ化されたデータからCarを作成し、ベストタイムを計算する関数
fn car_from_grouped_data(
    car_number: String,
    laps_with_metadata: Vec<LapWithMetadata>,
    driver_names: Vec<String>,
) -> Car {
    let drivers = drivers_from(driver_names);
    let car_metadata = &laps_with_metadata[0].metadata;
    let class = class_from(&car_metadata.class);
    let meta = metadata_from(car_number, drivers, class, car_metadata);

    let processed_laps = process_laps(laps_with_metadata);
    car_with_lap_data(meta, processed_laps)
}

/// ドライバー名のリストからDriverのリストを作成
fn drivers_from(driver_names: Vec<String>) -> Vec<Driver> {
    driver_names
        .into_iter()
        .enumerate()
        .map(|(i, name)| Driver::new(name, i == 0))
        .collect()
}

/// クラス文字列をClass enumにマッピング
fn class_from(class_str: &str) -> Class {
    match class_str {
        "HYPERCAR" => Class::HYPERCAR,
        "LMP2" => Class::LMP2,
        "LMGT3" => Class::LMGT3,
        unknown => {
            log::warn!("Unknown class '{}', falling back to None", unknown);
            Class::None
        }
    }
}

/// MetaDataを作成
fn metadata_from(
    car_number: String,
    drivers: Vec<Driver>,
    class: Class,
    car_metadata: &Metadata,
) -> MetaData {
    MetaData::new(
        car_number,
        drivers,
        class,
        car_metadata.group.clone(),
        car_metadata.team.clone(),
        car_metadata.manufacturer.clone(),
    )
}

/// ラップデータを含むCarを作成
fn car_with_lap_data(meta: MetaData, processed_laps: Vec<Lap>) -> Car {
    use motorsport::car::Status;

    let mut car = Car::new(meta, 1, processed_laps);
    car.status = Status::Racing;
    car
}

/// ベストタイムを追跡してラップを処理する関数（Elm実装に基づく）
fn process_laps(mut laps_with_metadata: Vec<LapWithMetadata>) -> Vec<Lap> {
    // ラップ番号順にソート
    laps_with_metadata.sort_by_key(|lap| lap.lap.lap);

    let mut best_lap_time: Option<u32> = None;
    let mut best_s1: Option<u32> = None;
    let mut best_s2: Option<u32> = None;
    let mut best_s3: Option<u32> = None;
    let mut mini_sector_bests = MiniSectorBests::new();
    let mut processed_laps = Vec::new();

    for lap_with_meta in laps_with_metadata {
        let lap = &lap_with_meta.lap;
        let csv_row = &lap_with_meta.csv_data;

        // 現在のラップタイムとセクタータイムを取得
        let current_lap_time = lap.time;
        let current_s1 = lap.sector_1;
        let current_s2 = lap.sector_2;
        let current_s3 = lap.sector_3;

        // ベストタイムを更新（0でない場合のみ）
        let update_best = |best: Option<u32>, current: u32| -> Option<u32> {
            if current > 0 {
                Some(best.map_or(current, |b| b.min(current)))
            } else {
                best
            }
        };

        best_lap_time = update_best(best_lap_time, current_lap_time);
        best_s1 = update_best(best_s1, current_s1);
        best_s2 = update_best(best_s2, current_s2);
        best_s3 = update_best(best_s3, current_s3);

        // ミニセクターのベストタイムを更新
        mini_sector_bests.update_from_raw(csv_row);

        // ミニセクター情報を作成（ベストタイム付き）
        let mini_sectors = build_mini_sectors_with_bests(csv_row, &mini_sector_bests);

        // 新しいLapを作成（ベストタイムとミニセクター情報とピット時間を設定）
        let processed_lap = Lap::new_with_mini_sectors(
            lap.car_number.clone(),
            lap.driver.clone(),
            lap.lap,
            lap.position,
            lap.time,
            best_lap_time.unwrap_or(0), // best field
            lap.sector_1,
            lap.sector_2,
            lap.sector_3,
            best_s1.unwrap_or(0), // s1_best field
            best_s2.unwrap_or(0), // s2_best field
            best_s3.unwrap_or(0), // s3_best field
            lap.elapsed,
            csv_row.pit_time, // ピット時間を追加
            mini_sectors,
        );

        processed_laps.push(processed_lap);
    }

    processed_laps
}

/// 各車両の各ラップでの位置を計算する
fn calculate_positions(cars: &mut [Car]) {
    if cars.is_empty() {
        return;
    }

    // スタートポジションを計算（1週目の経過時間順）
    start_positions(cars);

    // 最大ラップ数を取得
    let max_lap = cars
        .iter()
        .flat_map(|car| &car.laps)
        .map(|lap| lap.lap)
        .max()
        .unwrap_or(0);

    // 各ラップの位置を計算
    for lap_num in 1..=max_lap {
        position_for_lap(cars, lap_num);
    }
}

/// スタートポジションを計算（1週目の経過時間順）
fn start_positions(cars: &mut [Car]) {
    // 1週目のラップを収集してソート
    let mut lap1_times: Vec<(String, u32)> = cars
        .iter()
        .filter_map(|car| {
            car.laps
                .iter()
                .find(|lap| lap.lap == 1)
                .map(|lap| (car.meta_data.car_number.clone(), lap.elapsed))
        })
        .collect();
    lap1_times.sort_by_key(|(_, elapsed)| *elapsed);

    // スタートポジションを設定
    for car in cars.iter_mut() {
        if let Some(position) = lap1_times
            .iter()
            .position(|(car_num, _)| car_num == &car.meta_data.car_number)
        {
            // Elm互換のため0-basedのindexをそのまま使用
            // 注意: 将来的には1-basedの position + 1 に変更する可能性がある
            car.start_position = position as i32;
        }
    }
}

/// 特定のラップでの各車両の位置を計算
fn position_for_lap(cars: &mut [Car], lap_num: u32) {
    // 指定されたラップでの各車両の経過時間を収集してソート
    let mut lap_times: Vec<(String, u32, usize)> = cars
        .iter()
        .enumerate()
        .filter_map(|(car_idx, car)| {
            car.laps
                .iter()
                .find(|l| l.lap == lap_num)
                .map(|lap| (car.meta_data.car_number.clone(), lap.elapsed, car_idx))
        })
        .collect();
    lap_times.sort_by_key(|(_, elapsed, _)| *elapsed);

    // 各車両のラップに位置を設定
    for (position, (car_number, _, car_idx)) in lap_times.iter().enumerate() {
        if let Some(car) = cars.get_mut(*car_idx) {
            if let Some(lap) = car
                .laps
                .iter_mut()
                .find(|l| l.lap == lap_num && l.car_number == *car_number)
            {
                // Elm互換のため0-basedのindexをそのまま使用
                // 注意: 将来的には1-basedの position + 1 に変更する可能性がある
                lap.position = Some(position as u32);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // テストヘルパー関数
    fn create_test_metadata(team: &str, manufacturer: &str) -> Metadata {
        Metadata {
            class: "HYPERCAR".to_string(),
            group: "H".to_string(),
            team: team.to_string(),
            manufacturer: manufacturer.to_string(),
        }
    }

    fn create_test_extra_data(
        driver_number: u32,
        kph: f32,
        lap_improvement: i32,
        top_speed: Option<&str>,
    ) -> ExtraData {
        ExtraData {
            driver_number,
            lap_improvement,
            crossing_finish_line_in_pit: String::new(),
            s1_improvement: 0,
            s2_improvement: 0,
            s3_improvement: 0,
            kph,
            hour: "11:02:02.856".to_string(),
            top_speed: top_speed.map(|s| s.to_string()),
            pit_time: None,
            s1_raw: "23.155".to_string(),
            s2_raw: "29.928".to_string(),
            s3_raw: "42.282".to_string(),
            mini_sectors: None,
            // ミニセクターの生データ（テスト用）
            scl2_time: None,
            scl2_elapsed: None,
            z4_time: None,
            z4_elapsed: None,
            ip1_time: None,
            ip1_elapsed: None,
            z12_time: None,
            z12_elapsed: None,
            sclc_time: None,
            sclc_elapsed: None,
            a7_1_time: None,
            a7_1_elapsed: None,
            ip2_time: None,
            ip2_elapsed: None,
            a8_1_time: None,
            a8_1_elapsed: None,
            sclb_time: None,
            sclb_elapsed: None,
            porin_time: None,
            porin_elapsed: None,
            porout_time: None,
            porout_elapsed: None,
            pitref_time: None,
            pitref_elapsed: None,
            scl1_time: None,
            scl1_elapsed: None,
            fordout_time: None,
            fordout_elapsed: None,
            fl_time: None,
            fl_elapsed: None,
        }
    }

    fn create_test_lap_with_metadata(
        car_number: &str,
        driver: &str,
        lap_num: u32,
        position: Option<u32>,
        times: (u32, u32, u32, u32, u32), // (lap_time, s1, s2, s3, elapsed)
        metadata: Metadata,
        extra_data: ExtraData,
    ) -> LapWithMetadata {
        let (lap_time, s1, s2, s3, elapsed) = times;
        LapWithMetadata {
            lap: Lap::new(
                car_number.to_string(),
                driver.to_string(),
                lap_num,
                position,
                lap_time,
                lap_time,
                s1,
                s2,
                s3,
                s1,
                s2,
                s3,
                elapsed,
            ),
            metadata,
            csv_data: extra_data,
        }
    }

    #[test]
    fn test_group_laps_by_car() {
        let laps_with_metadata = vec![
            create_test_lap_with_metadata(
                "12",
                "Will STEVENS",
                1,
                Some(3),
                (95365, 23155, 29928, 42282, 95365),
                create_test_metadata("Hertz Team JOTA", "Porsche"),
                create_test_extra_data(1, 160.7, 0, None),
            ),
            create_test_lap_with_metadata(
                "12",
                "Robin FRIJNS",
                2,
                Some(2),
                (113610, 23155, 29928, 42282, 113610),
                create_test_metadata("Hertz Team JOTA", "Porsche"),
                create_test_extra_data(2, 165.2, 1, Some("298.6")),
            ),
            create_test_lap_with_metadata(
                "7",
                "Kamui KOBAYASHI",
                1,
                Some(1),
                (93291, 23119, 29188, 40984, 93291),
                create_test_metadata("Toyota Gazoo Racing", "Toyota"),
                create_test_extra_data(1, 175.0, 0, Some("298.6")),
            ),
        ];
        let cars = group_laps_by_car(laps_with_metadata);
        assert_eq!(cars.len(), 2);

        let car12 = cars
            .iter()
            .find(|c| c.meta_data.car_number == "12")
            .unwrap();
        assert_eq!(car12.laps.len(), 2);
        assert_eq!(car12.meta_data.team, "Hertz Team JOTA");
        assert_eq!(car12.meta_data.manufacturer, "Porsche");
        assert_eq!(car12.meta_data.drivers.len(), 2); // 2人のドライバー

        let car7 = cars.iter().find(|c| c.meta_data.car_number == "7").unwrap();
        assert_eq!(car7.laps.len(), 1);
        assert_eq!(car7.meta_data.team, "Toyota Gazoo Racing");
        assert_eq!(car7.meta_data.manufacturer, "Toyota");
        assert_eq!(car7.meta_data.drivers.len(), 1); // 1人のドライバー
    }

    #[test]
    fn test_best_time_tracking() {
        // Test best time tracking logic based on Elm implementation
        let team_metadata = create_test_metadata("Hertz Team JOTA", "Porsche");

        let laps_with_metadata = vec![
            // Lap 1: Sets initial best times
            create_test_lap_with_metadata(
                "12",
                "Will STEVENS",
                1,
                None,
                (95365, 23155, 29928, 42282, 95365),
                team_metadata.clone(),
                create_test_extra_data(1, 160.7, 0, None),
            ),
            // Lap 2: Faster in all areas - updates all bests
            create_test_lap_with_metadata(
                "12",
                "Will STEVENS",
                2,
                None,
                (92245, 22500, 29100, 40645, 187610),
                team_metadata.clone(),
                create_test_extra_data(1, 165.2, 1, None),
            ),
            // Lap 3: Slower overall but tests mixed sector performance
            create_test_lap_with_metadata(
                "12",
                "Will STEVENS",
                3,
                None,
                (94000, 23000, 29500, 41500, 281610),
                team_metadata,
                create_test_extra_data(1, 163.0, 0, None),
            ),
        ];

        let cars = group_laps_by_car(laps_with_metadata);
        assert_eq!(cars.len(), 1);

        let car = &cars[0];
        assert_eq!(car.laps.len(), 3);

        // Verify best time tracking across laps
        let expected_bests = [
            (95365, 23155, 29928, 42282), // Lap 1: initial bests
            (92245, 22500, 29100, 40645), // Lap 2: all improved
            (92245, 22500, 29100, 40645), // Lap 3: bests remain from lap 2
        ];

        for (i, (expected_lap_best, expected_s1, expected_s2, expected_s3)) in
            expected_bests.iter().enumerate()
        {
            let lap = &car.laps[i];
            assert_eq!(
                lap.best,
                *expected_lap_best,
                "Lap {} best time mismatch",
                i + 1
            );
            assert_eq!(lap.s1_best, *expected_s1, "Lap {} S1 best mismatch", i + 1);
            assert_eq!(lap.s2_best, *expected_s2, "Lap {} S2 best mismatch", i + 1);
            assert_eq!(lap.s3_best, *expected_s3, "Lap {} S3 best mismatch", i + 1);
        }
    }
}
