//! Source-data validation for parsed lap records.
//!
//! Three rules are checked, all with strict (0 ms) equality:
//!
//! 1. **Sector sum** — `sector_1 + sector_2 + sector_3 == lap_time` per row
//! 2. **Elapsed accumulation** — per car (sorted by `lap_number`),
//!    `elapsed[n] == sum(lap_time[1..=n])`
//! 3. **Hour ↔ elapsed correspondence** — `(hour - elapsed) mod 24h` is
//!    constant across the whole CSV (race start time invariant)
//!
//! Blank / 0 ms cells are not skipped; they participate in the comparison and
//! surface as violations. Violations are reported as warnings only — the CLI
//! never fails because of them.

use std::collections::HashMap;
use std::path::Path;

use motorsport::duration;

use crate::domain::{LapRecord, ParsedLap, sector_duration};

#[derive(Debug, Default)]
pub struct ValidationReport {
    pub issues: Vec<Issue>,
}

/// One detected violation. The variant determines which fields are meaningful;
/// each variant carries only the data its rule produced.
#[derive(Debug, Clone)]
pub enum Issue {
    /// `s1 + s2 + s3 != lap_time` for one row.
    SectorSum {
        car_number: String,
        lap_number: u32,
        lap_time_ms: u32,
        sectors_sum_ms: u32,
        blank_sectors: Vec<&'static str>,
    },
    /// Per-car cumulative-elapsed mismatch: the running sum of lap times up to
    /// this lap does not equal the recorded `elapsed`.
    ElapsedDrift {
        car_number: String,
        lap_number: u32,
        expected_ms: u32,
        actual_ms: u32,
    },
    /// Race-wide `(hour - elapsed) mod 24h` is not constant. Both fields are
    /// already folded into `[0, DAY_MS)`.
    HourOffset {
        car_number: String,
        lap_number: u32,
        expected_offset_ms: u32,
        actual_offset_ms: u32,
    },
    /// `hour` field is empty or unparseable — the rule cannot be evaluated.
    HourUnparseable {
        car_number: String,
        lap_number: u32,
        raw: String,
    },
}

impl Issue {
    pub fn kind_name(&self) -> &'static str {
        match self {
            Issue::SectorSum { .. } => "sector-sum",
            Issue::ElapsedDrift { .. } => "elapsed-drift",
            Issue::HourOffset { .. } => "hour-offset",
            Issue::HourUnparseable { .. } => "hour-unparseable",
        }
    }

    pub fn car_number(&self) -> &str {
        match self {
            Issue::SectorSum { car_number, .. }
            | Issue::ElapsedDrift { car_number, .. }
            | Issue::HourOffset { car_number, .. }
            | Issue::HourUnparseable { car_number, .. } => car_number,
        }
    }

    pub fn lap_number(&self) -> u32 {
        match self {
            Issue::SectorSum { lap_number, .. }
            | Issue::ElapsedDrift { lap_number, .. }
            | Issue::HourOffset { lap_number, .. }
            | Issue::HourUnparseable { lap_number, .. } => *lap_number,
        }
    }

    /// Renders one log line including both human-readable Duration strings and
    /// raw millisecond values, so the output is readable while still grep-able
    /// for exact ms.
    fn log_line(&self, source: &Path) -> String {
        let prefix = format!(
            "[{}] {}: car {} lap {}",
            source.display(),
            self.kind_name(),
            self.car_number(),
            self.lap_number(),
        );
        match self {
            Issue::SectorSum {
                lap_time_ms,
                sectors_sum_ms,
                blank_sectors,
                ..
            } => {
                let blank_note = if blank_sectors.is_empty() {
                    String::new()
                } else {
                    format!(" (blank: {})", blank_sectors.join(","))
                };
                format!(
                    "{prefix} expected={} ({}ms) actual={} ({}ms){blank_note}",
                    duration::to_string(*lap_time_ms),
                    lap_time_ms,
                    duration::to_string(*sectors_sum_ms),
                    sectors_sum_ms,
                )
            }
            Issue::ElapsedDrift {
                expected_ms,
                actual_ms,
                ..
            } => format!(
                "{prefix} expected={} ({}ms) actual={} ({}ms)",
                duration::to_string(*expected_ms),
                expected_ms,
                duration::to_string(*actual_ms),
                actual_ms,
            ),
            Issue::HourOffset {
                expected_offset_ms,
                actual_offset_ms,
                ..
            } => format!(
                "{prefix} expected={} ({}ms) actual={} ({}ms)",
                duration::to_string(*expected_offset_ms),
                expected_offset_ms,
                duration::to_string(*actual_offset_ms),
                actual_offset_ms,
            ),
            Issue::HourUnparseable { raw, .. } => format!("{prefix} raw={raw:?}"),
        }
    }
}

impl ValidationReport {
    /// Logs each issue at warn level, with a final summary line. No-op when
    /// the report is clean.
    pub fn log_details(&self, source: &Path) {
        for issue in &self.issues {
            log::warn!("{}", issue.log_line(source));
        }
        if !self.issues.is_empty() {
            log::warn!(
                "[{}] validation found {} issue(s)",
                source.display(),
                self.issues.len(),
            );
        }
    }
}

pub fn validate(records: &[LapRecord]) -> ValidationReport {
    if records.is_empty() {
        return ValidationReport::default();
    }
    ValidationReport {
        issues: [
            check_sector_sum(records),
            check_elapsed_accumulation(records),
            check_hour_elapsed_correspondence(records),
        ]
        .concat(),
    }
}

fn check_sector_sum(records: &[LapRecord]) -> Vec<Issue> {
    records
        .iter()
        .filter_map(|r| {
            let sum = sector_duration(&r.lap.sector_1)
                .saturating_add(sector_duration(&r.lap.sector_2))
                .saturating_add(sector_duration(&r.lap.sector_3));
            (sum != r.lap.time).then(|| Issue::SectorSum {
                car_number: r.lap.car_number.clone(),
                lap_number: r.lap.lap_number,
                lap_time_ms: r.lap.time,
                sectors_sum_ms: sum,
                blank_sectors: blank_sector_labels(&r.lap),
            })
        })
        .collect()
}

fn blank_sector_labels(lap: &ParsedLap) -> Vec<&'static str> {
    [
        (&lap.sector_1, "s1"),
        (&lap.sector_2, "s2"),
        (&lap.sector_3, "s3"),
    ]
    .into_iter()
    .filter_map(|(sector, name)| sector.is_err().then_some(name))
    .collect()
}

fn check_elapsed_accumulation(records: &[LapRecord]) -> Vec<Issue> {
    group_by_car(records)
        .into_iter()
        .flat_map(|(_, laps)| check_per_car_elapsed(laps))
        .collect()
}

/// Walks one car's laps in order, emitting one `ElapsedDrift` per row whose
/// recorded `elapsed` disagrees with the running sum of `lap.time`.
fn check_per_car_elapsed(mut laps: Vec<&LapRecord>) -> Vec<Issue> {
    laps.sort_by_key(|r| r.lap.lap_number);
    laps.into_iter()
        .scan(0u32, |running, r| {
            *running = running.saturating_add(r.lap.time);
            Some((*running, r))
        })
        .filter(|&(running, r)| running != r.lap.elapsed)
        .map(|(running, r)| Issue::ElapsedDrift {
            car_number: r.lap.car_number.clone(),
            lap_number: r.lap.lap_number,
            expected_ms: running,
            actual_ms: r.lap.elapsed,
        })
        .collect()
}

fn check_hour_elapsed_correspondence(records: &[LapRecord]) -> Vec<Issue> {
    records
        .iter()
        .scan(None::<u32>, |reference, r| {
            Some(match &r.stats.hour {
                Err(raw) => Some(Issue::HourUnparseable {
                    car_number: r.lap.car_number.clone(),
                    lap_number: r.lap.lap_number,
                    raw: raw.clone(),
                }),
                Ok(h) => {
                    let offset = h.offset_from(r.lap.elapsed);
                    match *reference {
                        None => {
                            *reference = Some(offset);
                            None
                        }
                        Some(expected) if expected != offset => Some(Issue::HourOffset {
                            car_number: r.lap.car_number.clone(),
                            lap_number: r.lap.lap_number,
                            expected_offset_ms: expected,
                            actual_offset_ms: offset,
                        }),
                        Some(_) => None,
                    }
                }
            })
        })
        .flatten()
        .collect()
}

/// Groups laps by car number in O(n), preserving CSV first-seen order so
/// reports match the ordering humans see in the source file.
fn group_by_car(records: &[LapRecord]) -> Vec<(&str, Vec<&LapRecord>)> {
    let grouped: HashMap<&str, (usize, Vec<&LapRecord>)> = records
        .iter()
        .enumerate()
        .fold(HashMap::new(), |mut acc, (index, r)| {
            acc.entry(r.lap.car_number.as_str())
                .or_insert_with(|| (index, Vec::new()))
                .1
                .push(r);
            acc
        });

    let mut entries: Vec<_> = grouped.into_iter().collect();
    entries.sort_by_key(|(_, (first_seen, _))| *first_seen);
    entries
        .into_iter()
        .map(|(key, (_, laps))| (key, laps))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{CarInfo, Hour, LapStats};
    use motorsport::duration::Duration;

    /// Test sector layout. `Some(d)` means a parsed duration; `None` means a
    /// blank cell (`Err(String::new())`).
    type Sectors = (Option<u32>, Option<u32>, Option<u32>);

    fn to_sector(value: Option<u32>) -> Result<Duration, String> {
        value.ok_or_else(String::new)
    }

    fn record(
        car_number: &str,
        lap_number: u32,
        time: u32,
        sectors: Sectors,
        elapsed: u32,
        hour: &str,
    ) -> LapRecord {
        LapRecord {
            lap: ParsedLap {
                car_number: car_number.to_string(),
                driver: "Driver".to_string(),
                lap_number,
                time,
                sector_1: to_sector(sectors.0),
                sector_2: to_sector(sectors.1),
                sector_3: to_sector(sectors.2),
                elapsed,
            },
            car: CarInfo {
                class: "HYPERCAR".to_string(),
                group: "H".to_string(),
                team: "Team".to_string(),
                manufacturer: "Manu".to_string(),
            },
            stats: LapStats {
                driver_number: 1,
                lap_improvement: 0,
                crossing_finish_line_in_pit: String::new(),
                s1_improvement: 0,
                s2_improvement: 0,
                s3_improvement: 0,
                kph: 0.0,
                hour: Hour::parse(hour),
                top_speed: None,
                pit_time: None,
            },
            mini_sectors: None,
        }
    }

    fn all_present(s1: u32, s2: u32, s3: u32) -> Sectors {
        (Some(s1), Some(s2), Some(s3))
    }

    #[test]
    fn validate_returns_clean_for_empty_records() {
        let report = validate(&[]);
        assert!(report.issues.is_empty());
    }

    #[test]
    fn sector_sum_passes_for_consistent_data() {
        let r = record(
            "12",
            1,
            95365,
            all_present(23155, 29928, 42282),
            95365,
            "11:02:02.856",
        );
        let report = validate(&[r]);
        assert!(
            !report
                .issues
                .iter()
                .any(|i| matches!(i, Issue::SectorSum { .. }))
        );
    }

    #[test]
    fn sector_sum_detects_mismatch() {
        let r = record(
            "12",
            1,
            95365,
            all_present(23155, 29928, 42283), // S3 off by 1 ms
            95365,
            "11:02:02.856",
        );
        let report = validate(&[r]);
        let issue = report
            .issues
            .iter()
            .find(|i| matches!(i, Issue::SectorSum { .. }))
            .expect("should have a sector-sum issue");
        match issue {
            Issue::SectorSum {
                car_number,
                lap_number,
                lap_time_ms,
                sectors_sum_ms,
                blank_sectors,
            } => {
                assert_eq!(car_number, "12");
                assert_eq!(*lap_number, 1);
                assert_eq!(*lap_time_ms, 95365);
                assert_eq!(*sectors_sum_ms, 95366);
                assert!(blank_sectors.is_empty());
            }
            _ => unreachable!(),
        }
    }

    #[test]
    fn sector_sum_flags_blank_sector_with_label() {
        let r = record(
            "12",
            1,
            95365,
            (None, Some(29928), Some(42282)), // S1 blank
            95365,
            "11:02:02.856",
        );
        let report = validate(&[r]);
        let issue = report
            .issues
            .iter()
            .find(|i| matches!(i, Issue::SectorSum { .. }))
            .expect("should have a sector-sum issue");
        match issue {
            Issue::SectorSum { blank_sectors, .. } => {
                assert_eq!(blank_sectors, &vec!["s1"]);
            }
            _ => unreachable!(),
        }
    }

    #[test]
    fn elapsed_accumulation_passes_for_consistent_data() {
        let records = vec![
            record(
                "12",
                1,
                95365,
                all_present(23155, 29928, 42282),
                95365,
                "11:02:02.856",
            ),
            record(
                "12",
                2,
                113610,
                all_present(26770, 29296, 57544),
                208975,
                "11:03:56.466",
            ),
        ];
        let report = validate(&records);
        assert!(
            !report
                .issues
                .iter()
                .any(|i| matches!(i, Issue::ElapsedDrift { .. }))
        );
    }

    #[test]
    fn elapsed_accumulation_detects_drift_per_car() {
        let records = vec![
            // Car A: clean.
            record(
                "A",
                1,
                95365,
                all_present(23155, 29928, 42282),
                95365,
                "11:02:02.856",
            ),
            record(
                "A",
                2,
                113610,
                all_present(26770, 29296, 57544),
                208975,
                "11:03:56.466",
            ),
            // Car B: lap 2 elapsed off by 100 ms.
            record(
                "B",
                1,
                95365,
                all_present(23155, 29928, 42282),
                95365,
                "11:02:02.856",
            ),
            record(
                "B",
                2,
                113610,
                all_present(26770, 29296, 57544),
                209075, // expected 208975
                "11:03:56.566",
            ),
        ];
        let report = validate(&records);
        let drifts: Vec<&Issue> = report
            .issues
            .iter()
            .filter(|i| matches!(i, Issue::ElapsedDrift { .. }))
            .collect();
        assert_eq!(drifts.len(), 1);
        match drifts[0] {
            Issue::ElapsedDrift {
                car_number,
                lap_number,
                expected_ms,
                actual_ms,
            } => {
                assert_eq!(car_number, "B");
                assert_eq!(*lap_number, 2);
                assert_eq!(*expected_ms, 208975);
                assert_eq!(*actual_ms, 209075);
            }
            _ => unreachable!(),
        }
    }

    #[test]
    fn hour_elapsed_correspondence_clean_for_constant_offset() {
        let records = vec![
            record(
                "12",
                1,
                95365,
                all_present(23155, 29928, 42282),
                95365,
                "11:02:02.856",
            ),
            record(
                "7",
                1,
                95421,
                all_present(23277, 29848, 42296),
                95421,
                "11:02:02.912",
            ),
        ];
        let report = validate(&records);
        assert!(
            !report
                .issues
                .iter()
                .any(|i| matches!(i, Issue::HourOffset { .. }))
        );
    }

    #[test]
    fn hour_elapsed_correspondence_handles_midnight_wrap() {
        // Race start 16:00:00.000. Reference offset = 16h = 57_600_000 ms.
        // After 8h elapsed, hour wraps to 00:00:00.
        // (0 - 8h) mod 24h = 16h → same offset.
        let records = vec![
            record(
                "12",
                1,
                95365,
                all_present(23155, 29928, 42282),
                95365,
                "16:01:35.365",
            ),
            record(
                "12",
                2,
                28_704_635,
                all_present(0, 0, 0),
                28_800_000,
                "00:00:00.000",
            ),
        ];
        let report = validate(&records);
        assert!(
            !report
                .issues
                .iter()
                .any(|i| matches!(i, Issue::HourOffset { .. })),
            "midnight wrap should not produce hour-offset issues, got: {:?}",
            report.issues,
        );
    }

    #[test]
    fn hour_elapsed_correspondence_detects_drift() {
        let records = vec![
            record(
                "12",
                1,
                95365,
                all_present(23155, 29928, 42282),
                95365,
                "11:02:02.856",
            ),
            record(
                "12",
                2,
                113610,
                all_present(26770, 29296, 57544),
                208975,
                "11:03:56.566", // 100 ms late vs reference
            ),
        ];
        let report = validate(&records);
        let issue = report
            .issues
            .iter()
            .find(|i| matches!(i, Issue::HourOffset { .. }))
            .expect("should detect hour-offset drift");
        match issue {
            Issue::HourOffset {
                car_number,
                lap_number,
                expected_offset_ms,
                actual_offset_ms,
            } => {
                assert_eq!(car_number, "12");
                assert_eq!(*lap_number, 2);
                assert_eq!(actual_offset_ms - expected_offset_ms, 100);
            }
            _ => unreachable!(),
        }
    }

    #[test]
    fn hour_unparseable_string_reported() {
        let records = vec![
            record(
                "12",
                1,
                95365,
                all_present(23155, 29928, 42282),
                95365,
                "", // empty
            ),
            record(
                "12",
                2,
                113610,
                all_present(26770, 29296, 57544),
                208975,
                "not-a-time",
            ),
        ];
        let report = validate(&records);
        let unparseable: Vec<&Issue> = report
            .issues
            .iter()
            .filter(|i| matches!(i, Issue::HourUnparseable { .. }))
            .collect();
        assert_eq!(unparseable.len(), 2);
    }

    #[test]
    fn log_line_includes_both_formatted_and_raw_ms() {
        let issue = Issue::SectorSum {
            car_number: "12".to_string(),
            lap_number: 1,
            lap_time_ms: 95365,
            sectors_sum_ms: 95366,
            blank_sectors: vec![],
        };
        let line = issue.log_line(Path::new("test.csv"));
        assert!(line.contains("1:35.365"), "missing formatted: {line}");
        assert!(line.contains("(95365ms)"), "missing raw ms: {line}");
        assert!(line.contains("car 12 lap 1"), "missing context: {line}");
        assert!(line.contains("sector-sum"), "missing kind: {line}");
    }

    #[test]
    fn log_line_includes_blank_note_when_present() {
        let issue = Issue::SectorSum {
            car_number: "12".to_string(),
            lap_number: 1,
            lap_time_ms: 95365,
            sectors_sum_ms: 0,
            blank_sectors: vec!["s1", "s2"],
        };
        let line = issue.log_line(Path::new("test.csv"));
        assert!(line.contains("(blank: s1,s2)"), "missing note: {line}");
    }
}
