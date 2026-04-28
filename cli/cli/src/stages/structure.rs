//! Stage 3: turn a list of [`CsvRow`] into a list of [`LapRecord`].
//!
//! Performs semantic conversion: parsing durations and bundling per-car
//! metadata into [`CarInfo`]. Lexical reading is the caller's responsibility
//! ([`csv_input`](super::csv_input)).

use motorsport::{Duration, duration};

use super::csv_input::CsvRow;
use crate::domain::{CarInfo, LapRecord, LapStats, ParsedLap, SectorPresence};

pub fn structure(rows: Vec<CsvRow>) -> Vec<LapRecord> {
    rows.into_iter().map(lap_record_from).collect()
}

struct ParsedDurations {
    time: Duration,
    s1: Duration,
    s2: Duration,
    s3: Duration,
    elapsed: Duration,
}

/// Parses the five required duration columns for one row, falling back to 0 on
/// failure.
///
/// An empty / whitespace-only value is treated as "missing" and silently
/// becomes 0 (a common shape in CSV exports). A non-empty value that fails to
/// parse also becomes 0, but emits a warning log first.
fn parse_required_durations(row: &CsvRow) -> ParsedDurations {
    let parse = |field: &'static str, value: &str| -> Duration {
        let trimmed = value.trim();
        if trimmed.is_empty() {
            return 0;
        }
        match duration::from_string(trimmed) {
            Some(d) => d,
            None => {
                log::warn!(
                    "car {} lap {}: unparseable {} value '{}', treating as 0",
                    row.car_number,
                    row.lap,
                    field,
                    value
                );
                0
            }
        }
    };

    ParsedDurations {
        time: parse("LAP_TIME", &row.lap_time),
        s1: parse("S1", &row.s1),
        s2: parse("S2", &row.s2),
        s3: parse("S3", &row.s3),
        elapsed: parse("ELAPSED", &row.elapsed),
    }
}

fn lap_record_from(row: CsvRow) -> LapRecord {
    let parsed = parse_required_durations(&row);
    let pit_time_dur = row
        .pit_time
        .as_deref()
        .filter(|s| !s.trim().is_empty())
        .and_then(motorsport::duration::from_string);

    let sectors = SectorPresence {
        s1: !row.s1.trim().is_empty(),
        s2: !row.s2.trim().is_empty(),
        s3: !row.s3.trim().is_empty(),
    };

    let lap = ParsedLap {
        car_number: row.car_number,
        driver: row.driver,
        lap_number: row.lap,
        time: parsed.time,
        sector_1: parsed.s1,
        sector_2: parsed.s2,
        sector_3: parsed.s3,
        elapsed: parsed.elapsed,
    };

    LapRecord {
        lap,
        car: CarInfo {
            class: row.class,
            group: row.group,
            team: row.team,
            manufacturer: row.manufacturer,
        },
        stats: LapStats {
            driver_number: row.driver_number,
            lap_improvement: row.lap_improvement,
            crossing_finish_line_in_pit: row.crossing_finish_line_in_pit,
            s1_improvement: row.s1_improvement,
            s2_improvement: row.s2_improvement,
            s3_improvement: row.s3_improvement,
            kph: row.kph,
            hour: row.hour,
            top_speed: row.top_speed,
            pit_time: pit_time_dur,
        },
        sectors,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::stages::csv_input;

    #[test]
    fn structure_maps_car_metadata_and_lap_basics() {
        let csv = "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS;\n12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;0:23.155;0:29.928;0:42.282;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;23.155;29.928;42.282;\n";
        let rows = csv_input::parse(csv);
        let records = structure(rows);

        assert_eq!(records.len(), 1);
        let r = &records[0];
        assert_eq!(r.lap.car_number, "12");
        assert_eq!(r.lap.driver, "Will STEVENS");
        assert_eq!(r.lap.time, 95365); // 1:35.365 → 95365 ms
        assert_eq!(r.car.team, "Hertz Team JOTA");
        assert_eq!(r.car.class, "HYPERCAR");
        assert!(r.sectors.s1);
        assert!(r.sectors.s2);
        assert!(r.sectors.s3);
    }

    /// Empty required-duration cells fall back to 0 without warning (a blank
    /// column is a valid input shape). The non-empty unparseable case (which
    /// does warn) is covered by an integration test.
    #[test]
    fn parse_required_durations_treats_empty_as_silent_zero() {
        let csv = "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER\n12;1;1;;0;;;0;;0;;0;160.7;;11:02:02.856;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche\n";
        let rows = csv_input::parse(csv);
        let records = structure(rows);
        assert_eq!(records.len(), 1);
        assert_eq!(records[0].lap.time, 0);
        assert_eq!(records[0].lap.sector_1, 0);
        assert_eq!(records[0].lap.sector_2, 0);
        assert_eq!(records[0].lap.sector_3, 0);
        assert_eq!(records[0].lap.elapsed, 0);
    }

    /// Whitespace-padded duration values parse cleanly via trim, with no
    /// spurious warning.
    #[test]
    fn parse_required_durations_handles_whitespace_padded_values() {
        let csv = "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER\n12;1;1; 1:35.365 ;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche\n";
        let rows = csv_input::parse(csv);
        let records = structure(rows);
        assert_eq!(records[0].lap.time, 95365);
    }
}
