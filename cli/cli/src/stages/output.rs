//! Stage 4b/5: JSON shape types and serialization helpers.
//!
//! The computation that fills these shapes lives in [`transform`](super::transform).

use motorsport::{Car, TimelineEvent, car, duration};
use serde::{Serialize, Serializer};

use crate::domain::LapRecord;
use crate::error::CliError;

/// Pretty-prints a serializable value as JSON (Stage 5).
pub fn to_json_pretty<T: Serialize>(value: &T, context: &'static str) -> Result<String, CliError> {
    serde_json::to_string_pretty(value).map_err(|source| CliError::Serialize { context, source })
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

/// Serializes KPH as an integer when it has no fractional part, preserving the
/// historical JSON shape.
fn serialize_speed<S>(kph: &f32, serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    if kph.fract() == 0.0 {
        serializer.serialize_i32(*kph as i32)
    } else {
        serializer.serialize_f32(*kph)
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

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MetadataOutput {
    pub name: String,
    pub starting_grid: Vec<StartingGrid>,
    pub timeline_events: Vec<TimelineEvent>,
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
    #[serde(serialize_with = "serialize_speed")]
    pub kph: f32,
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
}

/// JSON shape for an element of the `startingGrid` array.
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct StartingGrid {
    pub position: i32,
    pub car: car::MetaData,
}

/// Assembles the metadata output. `timeline_events` must be pre-computed by
/// the [`transform`](super::transform) stage — this module performs no domain
/// computation, only shape assembly.
pub(super) fn create_metadata_output(
    event_name: &str,
    cars: &[Car],
    timeline_events: Vec<TimelineEvent>,
) -> MetadataOutput {
    MetadataOutput {
        name: crate::events::display_name(event_name).to_string(),
        starting_grid: starting_grid_from(cars),
        timeline_events,
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
        kph: (stats.kph * 10.0).round() / 10.0,
        elapsed: duration::to_string(lap.elapsed),
        hour: stats.hour.clone(),
        top_speed: stats.top_speed.clone().unwrap_or_default(),
        driver_name: lap.driver.clone(),
        pit_time: stats
            .pit_time
            .map_or_else(String::new, duration::to_string),
        class: car.class.clone(),
        group: car.group.clone(),
        team: car.team.clone(),
        manufacturer: car.manufacturer.clone(),
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
    fn test_serialize_speed() {
        use serde_json::Value;

        // Integer value: trailing .0 is dropped.
        let result = serialize_speed(&186.0, serde_json::value::Serializer).unwrap();
        assert_eq!(result, Value::Number(186.into()));

        // Fractional value: kept as-is.
        let result = serialize_speed(&184.3, serde_json::value::Serializer).unwrap();
        if let Value::Number(n) = result {
            assert!((n.as_f64().unwrap() - 184.3).abs() < 0.001);
        } else {
            panic!("Expected number, got {result:?}");
        }
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
    fn test_create_output_includes_timeline_events() {
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

        // The provided timeline_events must be forwarded into MetadataOutput unchanged.
        let provided = vec![TimelineEvent {
            event_time: 0,
            event_type: motorsport::EventType::RaceStart,
        }];
        let output = create_metadata_output("test_event", &cars, provided);

        assert_eq!(output.timeline_events.len(), 1);
        assert_eq!(output.timeline_events[0].event_time, 0);
        assert_eq!(
            output.timeline_events[0].event_type,
            motorsport::EventType::RaceStart
        );
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

        let output = create_metadata_output("test_event", &cars, vec![]);

        assert_eq!(output.starting_grid.len(), 1);

        let grid_entry = &output.starting_grid[0];
        assert_eq!(grid_entry.position, 1);
        assert_eq!(grid_entry.car.car_number, "1");
        assert_eq!(grid_entry.car.team, "Test Team");
        assert_eq!(grid_entry.car.manufacturer, "Test Manufacturer");
    }
}
