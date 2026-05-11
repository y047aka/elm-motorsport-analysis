//! Stage 4b/5: JSON shape types and serialization helpers.
//!
//! The computation that fills these shapes lives in [`transform`](super::transform).

use motorsport::{Car, HourClock, car, duration};
use serde::{Serialize, Serializer};

use crate::domain::{LapRecord, MiniSectorTimes, with_mini_sector_names};
use crate::error::FileError;

/// Pretty-prints a serializable value as JSON (Stage 5).
pub fn to_json_pretty<T: Serialize>(value: &T, context: &'static str) -> Result<String, FileError> {
    serde_json::to_string_pretty(value).map_err(|source| FileError::Serialize { context, source })
}

/// Formats a sector time. If the CSV cell was blank (`present = false`) the
/// output stays blank; otherwise the parsed `Duration` is stringified. The
/// presence bit comes from [`SectorPresence`](crate::domain::SectorPresence).
fn format_sector_time(present: bool, sector_duration: u32) -> String {
    if present {
        duration::to_string(sector_duration)
    } else {
        String::new()
    }
}

/// Formats KPH as a string. The value is rounded to one decimal place; if the
/// result is a whole number the fractional part is omitted (e.g. `175.0` →
/// `"175"`, `160.7` → `"160.7"`).
fn format_kph(kph: f32) -> String {
    let rounded = (kph * 10.0).round() / 10.0;
    if rounded.fract() == 0.0 {
        format!("{}", rounded as i32)
    } else {
        format!("{:.1}", rounded)
    }
}

/// Serializes TopSpeed as a string, stripping a trailing `.0` when the raw
/// value is numeric. Unparseable inputs pass through unchanged.
fn serialize_top_speed<S>(top_speed: &str, serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    if top_speed.is_empty() {
        return serializer.serialize_str(top_speed);
    }

    if let Ok(speed) = top_speed.parse::<f32>() {
        if speed.fract() == 0.0 {
            serializer.serialize_str(&format!("{}", speed as i32))
        } else {
            serializer.serialize_str(top_speed)
        }
    } else {
        serializer.serialize_str(top_speed)
    }
}

/// One mini-sector's time and elapsed for the laps JSON output.
#[derive(Debug, Serialize)]
pub struct MiniSectorJsonEntry {
    pub time: Option<String>,
    pub elapsed: Option<String>,
}

macro_rules! define_mini_sectors_json {
    ($($name:ident),* $(,)?) => {
        /// All 15 Le Mans mini-sectors serialized to JSON.
        ///
        /// Field names are snake_case (e.g. `a7_1`) matching `MiniSectorId::json_key`.
        /// The struct is produced by `mini_sectors_json_from` and written as
        /// `"miniSectors"` inside `RawLap`.
        #[derive(Debug, Serialize)]
        pub struct MiniSectorsJson {
            $(pub $name: MiniSectorJsonEntry,)*
        }
    };
}
with_mini_sector_names!(define_mini_sectors_json);

fn mini_sectors_json_from(times: &MiniSectorTimes) -> MiniSectorsJson {
    macro_rules! build {
        ($($name:ident),* $(,)?) => {
            MiniSectorsJson {
                $($name: MiniSectorJsonEntry {
                    time: times.$name.time.clone(),
                    elapsed: times.$name.elapsed.clone(),
                },)*
            }
        };
    }
    with_mini_sector_names!(build)
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MetadataOutput {
    pub name: String,
    pub starting_grid: Vec<StartingGrid>,
}

/// JSON shape for an element of the `laps` array.
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RawLap {
    pub car_number: String,
    pub driver_number: u32,
    pub lap_number: u32,
    pub lap_time: String,
    pub lap_improvement: i32,
    pub crossing_finish_line_in_pit: String,
    pub s1: String,
    pub s1_improvement: i32,
    pub s2: String,
    pub s2_improvement: i32,
    pub s3: String,
    pub s3_improvement: i32,
    pub kph: String,
    pub elapsed: String,
    pub hour: String,
    #[serde(serialize_with = "serialize_top_speed")]
    pub top_speed: String,
    pub driver_name: String,
    pub pit_time: String,
    pub class: String,
    pub group: String,
    pub team: String,
    pub manufacturer: String,
    pub flag_at_fl: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mini_sectors: Option<MiniSectorsJson>,
}

/// JSON shape for an element of the `startingGrid` array.
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct StartingGrid {
    pub position: i32,
    pub car: car::MetaData,
}

/// Assembles the metadata output. This module performs no domain computation,
/// only shape assembly.
pub(super) fn create_metadata_output(event_name: &str, cars: &[Car]) -> MetadataOutput {
    MetadataOutput {
        name: crate::events::display_name(event_name).to_string(),
        starting_grid: starting_grid_from(cars),
    }
}

/// Projects `LapRecord`s into `RawLap`s. Called by `transform::build_outputs`
/// and re-exported through `for_testing`; not part of the public API.
pub(crate) fn create_laps_output(records: &[LapRecord]) -> Vec<RawLap> {
    records.iter().map(raw_lap_from).collect()
}

fn raw_lap_from(record: &LapRecord) -> RawLap {
    let lap = &record.lap;
    let car = &record.car;
    let stats = &record.stats;
    let sectors = &record.sectors;

    RawLap {
        car_number: lap.car_number.clone(),
        driver_number: stats.driver_number,
        lap_number: lap.lap_number,
        lap_time: duration::to_string(lap.time),
        lap_improvement: stats.lap_improvement,
        crossing_finish_line_in_pit: stats.crossing_finish_line_in_pit.clone(),
        s1: format_sector_time(sectors.s1, lap.sector_1),
        s1_improvement: stats.s1_improvement,
        s2: format_sector_time(sectors.s2, lap.sector_2),
        s2_improvement: stats.s2_improvement,
        s3: format_sector_time(sectors.s3, lap.sector_3),
        s3_improvement: stats.s3_improvement,
        kph: format_kph(stats.kph),
        elapsed: duration::to_string(lap.elapsed),
        hour: stats.hour.map(HourClock::format).unwrap_or_default(),
        top_speed: stats.top_speed.clone().unwrap_or_default(),
        driver_name: lap.driver.clone(),
        pit_time: stats
            .pit_time
            .map_or_else(String::new, duration::to_string),
        class: car.class.clone(),
        group: car.group.clone(),
        team: car.team.clone(),
        manufacturer: car.manufacturer.clone(),
        flag_at_fl: stats.flag_at_fl.clone(),
        mini_sectors: record
            .mini_sectors
            .as_ref()
            .map(mini_sectors_json_from),
    }
}

fn starting_grid_from(cars: &[Car]) -> Vec<StartingGrid> {
    cars.iter()
        .map(|car| StartingGrid {
            position: car.start_position,
            car: car.meta_data.clone(),
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_format_kph() {
        // Integer value: trailing .0 is dropped.
        assert_eq!(format_kph(186.0), "186");

        // Fractional value: kept as-is with one decimal.
        assert_eq!(format_kph(184.3), "184.3");

        // Rounding to one decimal.
        assert_eq!(format_kph(160.7), "160.7");
    }

    #[test]
    fn test_serialize_top_speed() {
        use serde_json::value::Serializer;

        let test_cases = vec![
            ("300.0", "300"),       // trailing .0 dropped
            ("288.8", "288.8"),     // fractional value preserved
            ("", ""),               // empty string preserved
            ("invalid", "invalid"), // unparseable value passes through
        ];

        for (input, expected) in test_cases {
            let result = serialize_top_speed(input, Serializer).unwrap();
            assert_eq!(
                result,
                serde_json::Value::String(expected.to_string()),
                "Expected '{input}' to be formatted as '{expected}', but got: {result:?}"
            );
        }
    }

    #[test]
    fn test_create_output_includes_starting_grid() {
        use motorsport::{Car, Class, Driver, Lap, MetaData};

        let drivers = vec![Driver::new("Test Driver".to_string(), false)];
        let metadata = MetaData::new(
            "1".to_string(),
            drivers,
            Class::HYPERCAR,
            "H".to_string(),
            "Test Team".to_string(),
            "Test Manufacturer".to_string(),
        );

        let laps = vec![Lap::new(
            "1".to_string(),
            "Test Driver".to_string(),
            1,
            Some(1),
            95365,
            95365,
            23155,
            29928,
            42282,
            23155,
            29928,
            42282,
            95365,
        )];

        let car = Car::new(metadata, 1, laps);
        let cars = vec![car];

        let output = create_metadata_output("test_event", &cars);

        assert_eq!(output.starting_grid.len(), 1);

        let grid_entry = &output.starting_grid[0];
        assert_eq!(grid_entry.position, 1);
        assert_eq!(grid_entry.car.car_number, "1");
        assert_eq!(grid_entry.car.team, "Test Team");
        assert_eq!(grid_entry.car.manufacturer, "Test Manufacturer");
    }
}
