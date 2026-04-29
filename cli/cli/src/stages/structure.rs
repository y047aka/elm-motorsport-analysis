//! Stage 3: turn a list of [`CsvRow`] into a list of [`LapRecord`].
//!
//! Performs semantic conversion: parsing durations, bundling per-car metadata
//! into [`CarInfo`], and collapsing 30 flat mini-sector columns into a
//! structured [`MiniSectorTimes`] (with events that lack them reduced to
//! `None`). Lexical reading is the caller's responsibility
//! ([`csv_input`](super::csv_input)).

use motorsport::duration::{self, Duration};

use super::csv_input::CsvRow;
use crate::domain::{
    CarInfo, Hour, LapRecord, LapStats, MiniSectorEntry, MiniSectorTimes, ParsedLap,
};

pub fn structure(rows: Vec<CsvRow>) -> Vec<LapRecord> {
    rows.into_iter().map(lap_record_from).collect()
}

/// Parses an optional `Duration` cell. Empty / whitespace becomes 0 silently
/// (a valid CSV shape); non-empty unparseable values become 0 with a warning.
fn parse_duration_cell(row: &CsvRow, field: &'static str, value: &str) -> Duration {
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
                value,
            );
            0
        }
    }
}

/// Parses a sector cell. `Ok(Duration)` on success; `Err(raw)` preserves the
/// original CSV value for blank or unparseable cells so it can round-trip to
/// JSON output. Non-empty unparseable values also warn.
fn parse_sector_cell(row: &CsvRow, field: &'static str, value: &str) -> Result<Duration, String> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        return Err(value.to_string());
    }
    match duration::from_string(trimmed) {
        Some(d) => Ok(d),
        None => {
            log::warn!(
                "car {} lap {}: unparseable {} value '{}', treating as blank",
                row.car_number,
                row.lap,
                field,
                value,
            );
            Err(value.to_string())
        }
    }
}

fn lap_record_from(row: CsvRow) -> LapRecord {
    let time = parse_duration_cell(&row, "LAP_TIME", &row.lap_time);
    let elapsed = parse_duration_cell(&row, "ELAPSED", &row.elapsed);
    let sector_1 = parse_sector_cell(&row, "S1", &row.s1);
    let sector_2 = parse_sector_cell(&row, "S2", &row.s2);
    let sector_3 = parse_sector_cell(&row, "S3", &row.s3);

    let pit_time_dur = row
        .pit_time
        .as_deref()
        .filter(|s| !s.trim().is_empty())
        .and_then(motorsport::duration::from_string);

    let hour = Hour::parse(&row.hour);

    let lap = ParsedLap {
        car_number: row.car_number,
        driver: row.driver,
        lap_number: row.lap,
        time,
        sector_1,
        sector_2,
        sector_3,
        elapsed,
    };

    let mini_sectors = MiniSectorTimes {
        scl2: MiniSectorEntry {
            time: row.scl2_time,
            elapsed: row.scl2_elapsed,
        },
        z4: MiniSectorEntry {
            time: row.z4_time,
            elapsed: row.z4_elapsed,
        },
        ip1: MiniSectorEntry {
            time: row.ip1_time,
            elapsed: row.ip1_elapsed,
        },
        z12: MiniSectorEntry {
            time: row.z12_time,
            elapsed: row.z12_elapsed,
        },
        sclc: MiniSectorEntry {
            time: row.sclc_time,
            elapsed: row.sclc_elapsed,
        },
        a7_1: MiniSectorEntry {
            time: row.a7_1_time,
            elapsed: row.a7_1_elapsed,
        },
        ip2: MiniSectorEntry {
            time: row.ip2_time,
            elapsed: row.ip2_elapsed,
        },
        a8_1: MiniSectorEntry {
            time: row.a8_1_time,
            elapsed: row.a8_1_elapsed,
        },
        sclb: MiniSectorEntry {
            time: row.sclb_time,
            elapsed: row.sclb_elapsed,
        },
        porin: MiniSectorEntry {
            time: row.porin_time,
            elapsed: row.porin_elapsed,
        },
        porout: MiniSectorEntry {
            time: row.porout_time,
            elapsed: row.porout_elapsed,
        },
        pitref: MiniSectorEntry {
            time: row.pitref_time,
            elapsed: row.pitref_elapsed,
        },
        scl1: MiniSectorEntry {
            time: row.scl1_time,
            elapsed: row.scl1_elapsed,
        },
        fordout: MiniSectorEntry {
            time: row.fordout_time,
            elapsed: row.fordout_elapsed,
        },
        fl: MiniSectorEntry {
            time: row.fl_time,
            elapsed: row.fl_elapsed,
        },
    }
    .into_optional();

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
            hour,
            top_speed: row.top_speed,
            pit_time: pit_time_dur,
        },
        mini_sectors,
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
        assert!(r.lap.sector_1.is_ok());
        assert!(r.lap.sector_2.is_ok());
        assert!(r.lap.sector_3.is_ok());
        assert!(r.mini_sectors.is_none());
    }

    #[test]
    fn structure_preserves_mini_sector_raw_strings_when_present() {
        let csv = "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS;SCL2_time;SCL2_elapsed;\n12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;0:23.155;0:29.928;0:42.282;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;23.155;29.928;42.282;8.112;0:08.112;\n";
        let rows = csv_input::parse(csv);
        let records = structure(rows);

        let mini = records[0].mini_sectors.as_ref().expect("should be Some");
        assert_eq!(mini.scl2.time.as_deref(), Some("8.112"));
        assert_eq!(mini.scl2.elapsed.as_deref(), Some("0:08.112"));
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
        assert!(records[0].lap.sector_1.is_err());
        assert!(records[0].lap.sector_2.is_err());
        assert!(records[0].lap.sector_3.is_err());
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
