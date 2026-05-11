//! Stage 4: build serializable intermediates from a list of [`LapRecord`].
//!
//! Mirrors Flix's `Motorsport.Metadata.fromRawLaps`: aggregates per-car
//! metadata and assigns starting-grid positions from lap-1 elapsed times.
//! Per-lap output is produced separately via [`output::create_laps_output`].

use indexmap::IndexMap;

use motorsport::{Driver, MetaData};

use super::output::{MetadataOutput, RawLap, StartingGrid, create_laps_output};
use crate::domain::LapRecord;

/// Builds every serializable intermediate for one race from a list of
/// [`LapRecord`]:
/// 1. project each `LapRecord` into a [`RawLap`] (by reference)
/// 2. consume `records` to build the starting grid
pub fn build_outputs(
    records: Vec<LapRecord>,
    event_name: &str,
) -> (Vec<RawLap>, MetadataOutput) {
    let raw_laps = create_laps_output(&records);
    let starting_grid = build_starting_grid(records);
    let metadata = MetadataOutput {
        name: crate::events::display_name(event_name).to_string(),
        starting_grid,
    };
    (raw_laps, metadata)
}

/// Aggregates records by car number (preserving CSV first-seen order),
/// then ranks cars by lap-1 elapsed time to assign starting positions.
pub fn build_starting_grid(records: Vec<LapRecord>) -> Vec<StartingGrid> {
    let builds = build_cars(&records);

    // Cars that completed lap 1, ranked by elapsed time, get 0-based positions.
    // We compute positions by index into `builds` to avoid carrying borrows
    // across the subsequent move.
    let mut ranked: Vec<(usize, u32)> = builds
        .iter()
        .enumerate()
        .filter_map(|(i, b)| b.lap1_elapsed.map(|e| (i, e)))
        .collect();
    ranked.sort_by_key(|(_, elapsed)| *elapsed);

    let mut positions = vec![0_i32; builds.len()];
    for (rank, (build_idx, _)) in ranked.into_iter().enumerate() {
        positions[build_idx] = rank as i32;
    }

    builds
        .into_iter()
        .zip(positions)
        .map(|(b, position)| StartingGrid {
            position,
            car: b.meta,
        })
        .collect()
}

struct CarBuild {
    meta: MetaData,
    lap1_elapsed: Option<u32>,
}

fn build_cars(records: &[LapRecord]) -> Vec<CarBuild> {
    // IndexMap preserves CSV first-seen order without a separate index field.
    let mut grouped: IndexMap<&str, (Vec<String>, Option<u32>, &LapRecord)> = IndexMap::new();

    for record in records {
        let car_number = record.lap.car_number.as_str();
        let driver_name = &record.lap.driver;
        let lap1 = (record.lap.lap_number == 1).then_some(record.lap.elapsed);

        grouped
            .entry(car_number)
            .and_modify(|(drivers, l1, _)| {
                if !drivers.iter().any(|d| d == driver_name) {
                    drivers.push(driver_name.clone());
                }
                if l1.is_none() {
                    *l1 = lap1;
                }
            })
            .or_insert_with(|| (vec![driver_name.clone()], lap1, record));
    }

    grouped
        .into_iter()
        .map(|(car_number, (driver_names, lap1, first_record))| {
            let car_info = &first_record.car;
            let meta = MetaData::new(
                car_number.to_string(),
                driver_names.into_iter().map(Driver::new).collect(),
                car_info.class.clone(),
                car_info.group.clone(),
                car_info.team.clone(),
                car_info.manufacturer.clone(),
            );
            CarBuild {
                meta,
                lap1_elapsed: lap1,
            }
        })
        .collect()
}


#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{CarInfo, LapStats, ParsedLap, SectorPresence};

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
        kph: &str,
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
            kph: kph.to_string(),
            flag_at_fl: String::new(),
            hour: motorsport::HourClock::parse("11:02:02.856"),
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
    fn starting_grid_ranks_by_lap1_elapsed() {
        let records = vec![
            test_record(
                "12",
                "Will STEVENS",
                1,
                (95365, 23155, 29928, 42282, 95365),
                test_car_info("Hertz Team JOTA", "Porsche"),
                test_stats(1, "160.7", 0, None),
            ),
            test_record(
                "12",
                "Robin FRIJNS",
                2,
                (113610, 23155, 29928, 42282, 113610),
                test_car_info("Hertz Team JOTA", "Porsche"),
                test_stats(2, "165.2", 1, Some("298.6")),
            ),
            test_record(
                "7",
                "Kamui KOBAYASHI",
                1,
                (93291, 23119, 29188, 40984, 93291),
                test_car_info("Toyota Gazoo Racing", "Toyota"),
                test_stats(1, "175.0", 0, Some("298.6")),
            ),
        ];
        let grid = build_starting_grid(records);
        assert_eq!(grid.len(), 2);

        // Car 7 has the smaller lap-1 elapsed → position 0.
        let car7 = grid.iter().find(|g| g.car.car_number == "7").unwrap();
        assert_eq!(car7.position, 0);
        assert_eq!(car7.car.team, "Toyota Gazoo Racing");
        assert_eq!(car7.car.drivers.len(), 1);

        let car12 = grid.iter().find(|g| g.car.car_number == "12").unwrap();
        assert_eq!(car12.position, 1);
        assert_eq!(car12.car.team, "Hertz Team JOTA");
        assert_eq!(car12.car.drivers.len(), 2);
    }
}
