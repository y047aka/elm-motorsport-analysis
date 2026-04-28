//! Stage 4: build serializable intermediates from a list of [`LapRecord`].
//!
//! Two outputs come from the same `Vec<LapRecord>`:
//! 1. a flat `Vec<RawLap>` (one entry per CSV row)
//! 2. a `MetadataOutput` whose starting grid is sorted by lap-1 elapsed time
//!
//! The JSON shape types ([`RawLap`] / [`MetadataOutput`]) live in
//! [`output`](super::output); this module fills them in.

use std::collections::HashMap;

use motorsport::Duration;

use super::output::{
    CarMeta, Driver, MetadataOutput, RawLap, StartingGrid, create_laps_output,
};
use crate::domain::LapRecord;

pub fn build_outputs(records: Vec<LapRecord>, event_name: &str) -> (Vec<RawLap>, MetadataOutput) {
    let raw_laps = create_laps_output(&records);
    let cars = aggregate_cars(records);
    let metadata = create_metadata_output(event_name, cars);
    (raw_laps, metadata)
}

/// Per-car summary built up while walking laps in CSV order. Only what the
/// metadata JSON needs.
pub(crate) struct CarBuild {
    pub car_number: String,
    pub drivers: Vec<String>,
    pub class: String,
    pub group: String,
    pub team: String,
    pub manufacturer: String,
    /// Elapsed time at the end of lap 1, used to sort the starting grid.
    pub lap1_elapsed: Option<Duration>,
}

/// Groups laps by car number, preserving CSV order of first appearance.
/// Captures unique drivers per car and the lap-1 elapsed time.
pub(crate) fn aggregate_cars(records: Vec<LapRecord>) -> Vec<CarBuild> {
    let mut cars: Vec<CarBuild> = Vec::new();
    for record in records {
        let LapRecord {
            lap,
            car: car_info,
            ..
        } = record;
        let lap1 = if lap.lap_number == 1 {
            Some(lap.elapsed)
        } else {
            None
        };
        match cars.iter_mut().find(|c| c.car_number == lap.car_number) {
            Some(existing) => {
                if !existing.drivers.contains(&lap.driver) {
                    existing.drivers.push(lap.driver);
                }
                if existing.lap1_elapsed.is_none() {
                    existing.lap1_elapsed = lap1;
                }
            }
            None => {
                cars.push(CarBuild {
                    car_number: lap.car_number,
                    drivers: vec![lap.driver],
                    class: car_info.class,
                    group: car_info.group,
                    team: car_info.team,
                    manufacturer: car_info.manufacturer,
                    lap1_elapsed: lap1,
                });
            }
        }
    }
    cars
}

fn create_metadata_output(event_name: &str, cars: Vec<CarBuild>) -> MetadataOutput {
    let positions = start_positions(&cars);
    let starting_grid = cars
        .into_iter()
        .map(|c| {
            // Cars without a lap-1 entry fall back to position 1 (matches the
            // historical default from the previous Car::new(_, 1, _) shape).
            let position = positions.get(&c.car_number).copied().unwrap_or(1);
            StartingGrid {
                position,
                car: CarMeta {
                    car_number: c.car_number,
                    drivers: c
                        .drivers
                        .into_iter()
                        .map(|name| Driver { name })
                        .collect(),
                    class: c.class,
                    group: c.group,
                    team: c.team,
                    manufacturer: c.manufacturer,
                },
            }
        })
        .collect();

    MetadataOutput {
        name: crate::events::display_name(event_name).to_string(),
        starting_grid,
    }
}

/// Sorts cars by lap-1 elapsed time and assigns 0-based starting positions.
/// Cars without a lap-1 entry are absent from the returned map.
fn start_positions(cars: &[CarBuild]) -> HashMap<String, i32> {
    let mut order: Vec<(&str, Duration)> = cars
        .iter()
        .filter_map(|c| c.lap1_elapsed.map(|e| (c.car_number.as_str(), e)))
        .collect();
    order.sort_by_key(|(_, e)| *e);
    order
        .into_iter()
        .enumerate()
        .map(|(i, (cn, _))| (cn.to_string(), i as i32))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{CarInfo, LapStats, ParsedLap, SectorPresence};

    fn test_record(
        car_number: &str,
        driver: &str,
        lap_num: u32,
        elapsed: Duration,
        team: &str,
    ) -> LapRecord {
        LapRecord {
            lap: ParsedLap {
                car_number: car_number.to_string(),
                driver: driver.to_string(),
                lap_number: lap_num,
                time: 0,
                sector_1: 0,
                sector_2: 0,
                sector_3: 0,
                elapsed,
            },
            car: CarInfo {
                class: "HYPERCAR".to_string(),
                group: "H".to_string(),
                team: team.to_string(),
                manufacturer: "Porsche".to_string(),
            },
            stats: LapStats {
                driver_number: 1,
                lap_improvement: 0,
                crossing_finish_line_in_pit: String::new(),
                s1_improvement: 0,
                s2_improvement: 0,
                s3_improvement: 0,
                kph: 0.0,
                hour: String::new(),
                top_speed: None,
                pit_time: None,
            },
            sectors: SectorPresence {
                s1: false,
                s2: false,
                s3: false,
            },
        }
    }

    #[test]
    fn aggregate_cars_groups_by_car_and_collects_unique_drivers() {
        let records = vec![
            test_record("12", "Will STEVENS", 1, 95365, "Hertz Team JOTA"),
            test_record("7", "Kamui KOBAYASHI", 1, 93291, "Toyota Gazoo Racing"),
            test_record("12", "Robin FRIJNS", 2, 113610, "Hertz Team JOTA"),
            test_record("12", "Will STEVENS", 3, 145000, "Hertz Team JOTA"),
        ];
        let cars = aggregate_cars(records);
        assert_eq!(cars.len(), 2);
        assert_eq!(cars[0].car_number, "12");
        assert_eq!(cars[0].drivers, vec!["Will STEVENS", "Robin FRIJNS"]);
        assert_eq!(cars[0].lap1_elapsed, Some(95365));
        assert_eq!(cars[1].car_number, "7");
        assert_eq!(cars[1].drivers, vec!["Kamui KOBAYASHI"]);
        assert_eq!(cars[1].lap1_elapsed, Some(93291));
    }

    #[test]
    fn start_positions_orders_by_lap1_elapsed() {
        let records = vec![
            test_record("12", "Will STEVENS", 1, 95365, "Hertz Team JOTA"),
            test_record("7", "Kamui KOBAYASHI", 1, 93291, "Toyota Gazoo Racing"),
        ];
        let cars = aggregate_cars(records);
        let positions = start_positions(&cars);
        assert_eq!(positions.get("7"), Some(&0));
        assert_eq!(positions.get("12"), Some(&1));
    }
}
