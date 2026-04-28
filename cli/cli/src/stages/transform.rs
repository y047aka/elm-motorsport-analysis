//! Stage 4: build serializable intermediates from a list of [`LapRecord`].
//!
//! This stage owns the domain-level computation:
//! - grouping laps by car (preserving CSV order)
//! - accumulating best times (lap / S1 / S2 / S3 / mini-sector)
//! - computing per-lap positions (including the starting grid)
//!
//! The JSON shape types ([`RawLap`] / [`MetadataOutput`]) live in
//! [`output`](super::output); this module fills them in.

use std::collections::HashMap;

use motorsport::{Car, Class, Driver, Lap, MetaData, MiniSector, MiniSectors};

use super::output::{MetadataOutput, RawLap, create_laps_output, create_metadata_output};
use crate::domain::{
    BestTimes, LapRecord, MiniSectorBests, MiniSectorTimes, ParsedLap, with_mini_sector_names,
};

/// Builds every serializable intermediate for one race from a list of
/// [`LapRecord`].
///
/// Internally this runs in order:
/// 1. project each `LapRecord` into a [`RawLap`] (by reference)
/// 2. consume `records` to aggregate by car into a [`Car`] list
/// 3. assemble [`MetadataOutput`] (event name + starting grid)
///
/// Step 1 borrows `records` while step 2 moves it, so the order matters — but
/// the constraint is encapsulated here, not in the caller.
pub fn build_outputs(
    records: Vec<LapRecord>,
    event_name: &str,
) -> (Vec<RawLap>, MetadataOutput) {
    let raw_laps = create_laps_output(&records);
    let cars = group_laps_by_car(records);
    let metadata = create_metadata_output(event_name, &cars);
    (raw_laps, metadata)
}

pub fn group_laps_by_car(records: Vec<LapRecord>) -> Vec<Car> {
    let mut cars = build_cars(records);
    calculate_positions(&mut cars);
    cars
}

fn build_cars(records: Vec<LapRecord>) -> Vec<Car> {
    // Index tags each entry with its first-seen position so CSV order can be
    // restored after the HashMap scramble.
    let mut grouped: HashMap<String, (Vec<LapRecord>, Vec<String>, usize)> = HashMap::new();

    for (index, record) in records.into_iter().enumerate() {
        let car_number = record.lap.car_number.clone();
        let driver_name = record.lap.driver.clone();

        let entry = grouped
            .entry(car_number)
            .or_insert_with(|| (Vec::new(), Vec::new(), index));
        entry.0.push(record);
        if !entry.1.contains(&driver_name) {
            entry.1.push(driver_name);
        }
    }

    let mut cars_with_index: Vec<(usize, Car)> = grouped
        .into_iter()
        .map(|(car_number, (records, driver_names, first_index))| {
            let car = car_from_group(car_number, records, driver_names);
            (first_index, car)
        })
        .collect();

    cars_with_index.sort_by_key(|(index, _)| *index);
    cars_with_index.into_iter().map(|(_, car)| car).collect()
}

fn car_from_group(car_number: String, records: Vec<LapRecord>, driver_names: Vec<String>) -> Car {
    let drivers = drivers_from(driver_names);
    let car_info = &records[0].car;
    let class = class_from(&car_info.class);
    let meta = MetaData::new(
        car_number,
        drivers,
        class,
        car_info.group.clone(),
        car_info.team.clone(),
        car_info.manufacturer.clone(),
    );

    let processed_laps = process_laps(records);

    Car::new(meta, 1, processed_laps)
}

fn drivers_from(driver_names: Vec<String>) -> Vec<Driver> {
    driver_names
        .into_iter()
        .enumerate()
        .map(|(i, name)| Driver::new(name, i == 0))
        .collect()
}

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

/// Walks laps in order, accumulating best times and materialising each [`Lap`].
fn process_laps(mut records: Vec<LapRecord>) -> Vec<Lap> {
    records.sort_by_key(|r| r.lap.lap_number);

    let mut bests = BestTimes::default();

    records
        .into_iter()
        .map(|record| {
            // (a) accumulator update — the only mutation point per iteration
            bests.update_lap_and_sectors(
                record.lap.time,
                record.lap.sector_1,
                record.lap.sector_2,
                record.lap.sector_3,
            );
            if let Some(mini) = &record.mini_sectors {
                bests.update_mini(mini);
            }

            // (b) pure readout — build the final Lap from the snapshotted bests
            let mini_sectors = record
                .mini_sectors
                .as_ref()
                .map(|mini| build_mini_sectors(mini, &bests.mini));
            finalized_lap(record.lap, &bests, mini_sectors)
        })
        .collect()
}

/// Assembles a `motorsport::Lap` from a parsed lap, the accumulated bests, and
/// optional mini-sector data.
///
/// This is the only place where `motorsport::Lap` is constructed. `position`
/// is left `None`; [`calculate_positions`] fills it in after grouping.
fn finalized_lap(
    lap: ParsedLap,
    bests: &BestTimes,
    mini_sectors: Option<MiniSectors>,
) -> Lap {
    Lap::new_with_mini_sectors(
        lap.car_number,
        lap.driver,
        lap.lap_number,
        None,
        lap.time,
        bests.lap.unwrap_or(0),
        lap.sector_1,
        lap.sector_2,
        lap.sector_3,
        bests.s1.unwrap_or(0),
        bests.s2.unwrap_or(0),
        bests.s3.unwrap_or(0),
        lap.elapsed,
        mini_sectors,
    )
}

/// Assembles [`MiniSectors`] by combining the current lap's times with the
/// accumulated bests. The 15 sector names come from
/// [`with_mini_sector_names!`](crate::domain::with_mini_sector_names).
fn build_mini_sectors(times: &MiniSectorTimes, bests: &MiniSectorBests) -> MiniSectors {
    // `mini_sectors_from!` reads `times` and `bests` from the enclosing scope
    // — macro_rules! hygiene resolves those at the call site. Rename either
    // variable and this macro body has to follow.
    macro_rules! mini_sectors_from {
        ($($name:ident),* $(,)?) => {
            MiniSectors {
                $($name: MiniSector {
                    time: times.$name.parse_time(),
                    elapsed: times.$name.parse_elapsed(),
                    best: bests.$name.unwrap_or(0),
                },)*
            }
        };
    }
    with_mini_sector_names!(mini_sectors_from)
}

fn calculate_positions(cars: &mut [Car]) {
    if cars.is_empty() {
        return;
    }

    start_positions(cars);

    let max_lap = cars
        .iter()
        .flat_map(|car| &car.laps)
        .map(|lap| lap.lap)
        .max()
        .unwrap_or(0);

    for lap_num in 1..=max_lap {
        position_for_lap(cars, lap_num);
    }
}

fn start_positions(cars: &mut [Car]) {
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

    for car in cars.iter_mut() {
        if let Some(position) = lap1_times
            .iter()
            .position(|(car_num, _)| car_num == &car.meta_data.car_number)
        {
            // 0-based index, for parity with the Elm side.
            car.start_position = position as i32;
        }
    }
}

fn position_for_lap(cars: &mut [Car], lap_num: u32) {
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

    for (position, (car_number, _, car_idx)) in lap_times.iter().enumerate() {
        if let Some(car) = cars.get_mut(*car_idx) {
            if let Some(lap) = car
                .laps
                .iter_mut()
                .find(|l| l.lap == lap_num && l.car_number == *car_number)
            {
                // 0-based index, for parity with the Elm side.
                lap.position = Some(position as u32);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{CarInfo, LapStats, SectorPresence};

    fn test_car_info(team: &str, manufacturer: &str) -> CarInfo {
        CarInfo {
            class: "HYPERCAR".to_string(),
            group: "H".to_string(),
            team: team.to_string(),
            manufacturer: manufacturer.to_string(),
        }
    }

    fn test_stats(
        driver_number: u32,
        kph: f32,
        lap_improvement: i32,
        top_speed: Option<&str>,
    ) -> LapStats {
        LapStats {
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
        }
    }

    fn test_sectors() -> SectorPresence {
        SectorPresence {
            s1: true,
            s2: true,
            s3: true,
        }
    }

    fn test_record(
        car_number: &str,
        driver: &str,
        lap_num: u32,
        _position: Option<u32>,
        times: (u32, u32, u32, u32, u32),
        car: CarInfo,
        stats: LapStats,
    ) -> LapRecord {
        let (lap_time, s1, s2, s3, elapsed) = times;
        LapRecord {
            lap: ParsedLap {
                car_number: car_number.to_string(),
                driver: driver.to_string(),
                lap_number: lap_num,
                time: lap_time,
                sector_1: s1,
                sector_2: s2,
                sector_3: s3,
                elapsed,
            },
            car,
            stats,
            sectors: test_sectors(),
            mini_sectors: None,
        }
    }

    #[test]
    fn test_group_laps_by_car() {
        let records = vec![
            test_record(
                "12",
                "Will STEVENS",
                1,
                Some(3),
                (95365, 23155, 29928, 42282, 95365),
                test_car_info("Hertz Team JOTA", "Porsche"),
                test_stats(1, 160.7, 0, None),
            ),
            test_record(
                "12",
                "Robin FRIJNS",
                2,
                Some(2),
                (113610, 23155, 29928, 42282, 113610),
                test_car_info("Hertz Team JOTA", "Porsche"),
                test_stats(2, 165.2, 1, Some("298.6")),
            ),
            test_record(
                "7",
                "Kamui KOBAYASHI",
                1,
                Some(1),
                (93291, 23119, 29188, 40984, 93291),
                test_car_info("Toyota Gazoo Racing", "Toyota"),
                test_stats(1, 175.0, 0, Some("298.6")),
            ),
        ];
        let cars = group_laps_by_car(records);
        assert_eq!(cars.len(), 2);

        let car12 = cars
            .iter()
            .find(|c| c.meta_data.car_number == "12")
            .unwrap();
        assert_eq!(car12.laps.len(), 2);
        assert_eq!(car12.meta_data.team, "Hertz Team JOTA");
        assert_eq!(car12.meta_data.manufacturer, "Porsche");
        assert_eq!(car12.meta_data.drivers.len(), 2);

        let car7 = cars.iter().find(|c| c.meta_data.car_number == "7").unwrap();
        assert_eq!(car7.laps.len(), 1);
        assert_eq!(car7.meta_data.team, "Toyota Gazoo Racing");
        assert_eq!(car7.meta_data.manufacturer, "Toyota");
        assert_eq!(car7.meta_data.drivers.len(), 1);
    }

    #[test]
    fn test_best_time_tracking() {
        let car_info = test_car_info("Hertz Team JOTA", "Porsche");

        let records = vec![
            test_record(
                "12",
                "Will STEVENS",
                1,
                None,
                (95365, 23155, 29928, 42282, 95365),
                car_info.clone(),
                test_stats(1, 160.7, 0, None),
            ),
            test_record(
                "12",
                "Will STEVENS",
                2,
                None,
                (92245, 22500, 29100, 40645, 187610),
                car_info.clone(),
                test_stats(1, 165.2, 1, None),
            ),
            test_record(
                "12",
                "Will STEVENS",
                3,
                None,
                (94000, 23000, 29500, 41500, 281610),
                car_info,
                test_stats(1, 163.0, 0, None),
            ),
        ];

        let cars = group_laps_by_car(records);
        assert_eq!(cars.len(), 1);

        let car = &cars[0];
        assert_eq!(car.laps.len(), 3);

        let expected_bests = [
            (95365, 23155, 29928, 42282),
            (92245, 22500, 29100, 40645),
            (92245, 22500, 29100, 40645),
        ];

        for (i, (expected_lap_best, expected_s1, expected_s2, expected_s3)) in
            expected_bests.iter().enumerate()
        {
            let lap = &car.laps[i];
            assert_eq!(lap.best, *expected_lap_best, "Lap {} best mismatch", i + 1);
            assert_eq!(lap.s1_best, *expected_s1, "Lap {} S1 best mismatch", i + 1);
            assert_eq!(lap.s2_best, *expected_s2, "Lap {} S2 best mismatch", i + 1);
            assert_eq!(lap.s3_best, *expected_s3, "Lap {} S3 best mismatch", i + 1);
        }
    }
}
