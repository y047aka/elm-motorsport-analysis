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
//! surface as violations.

use std::path::Path;

use motorsport::duration;

use crate::domain::LapRecord;

/// One day in milliseconds. Used to fold hour/elapsed offsets so 24h races
/// crossing midnight stay on a single equivalence class.
const DAY_MS: i64 = 86_400_000;

#[derive(Debug, Default)]
pub struct ValidationReport {
    pub issues: Vec<Issue>,
}

#[derive(Debug, Clone)]
pub struct Issue {
    pub kind: IssueKind,
    pub car_number: String,
    pub lap_number: u32,
    pub expected_ms: i64,
    pub actual_ms: i64,
    pub note: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum IssueKind {
    SectorSum,
    ElapsedDrift,
    HourOffset,
    HourUnparseable,
}

impl IssueKind {
    fn as_str(&self) -> &'static str {
        match self {
            IssueKind::SectorSum => "sector-sum",
            IssueKind::ElapsedDrift => "elapsed-drift",
            IssueKind::HourOffset => "hour-offset",
            IssueKind::HourUnparseable => "hour-unparseable",
        }
    }
}

impl ValidationReport {
    pub fn is_clean(&self) -> bool {
        self.issues.is_empty()
    }

    pub fn issue_count(&self) -> usize {
        self.issues.len()
    }

    /// Logs each issue at warn level, with a final summary line.
    pub fn log_details(&self, source: &Path) {
        for issue in &self.issues {
            let note = issue
                .note
                .as_deref()
                .map(|n| format!(" ({n})"))
                .unwrap_or_default();
            log::warn!(
                "[{}] {}: car {} lap {} expected={} actual={}{}",
                source.display(),
                issue.kind.as_str(),
                issue.car_number,
                issue.lap_number,
                issue.expected_ms,
                issue.actual_ms,
                note,
            );
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
    let mut report = ValidationReport::default();
    if records.is_empty() {
        return report;
    }
    check_sector_sum(records, &mut report);
    check_elapsed_accumulation(records, &mut report);
    check_hour_elapsed_correspondence(records, &mut report);
    report
}

fn check_sector_sum(records: &[LapRecord], report: &mut ValidationReport) {
    for r in records {
        let sum = i64::from(r.lap.sector_1) + i64::from(r.lap.sector_2) + i64::from(r.lap.sector_3);
        let lap_time = i64::from(r.lap.time);
        if sum != lap_time {
            let note = blank_sector_note(r);
            report.issues.push(Issue {
                kind: IssueKind::SectorSum,
                car_number: r.lap.car_number.clone(),
                lap_number: r.lap.lap_number,
                expected_ms: lap_time,
                actual_ms: sum,
                note,
            });
        }
    }
}

fn blank_sector_note(r: &LapRecord) -> Option<String> {
    let mut blanks = Vec::new();
    if !r.sectors.s1 {
        blanks.push("s1");
    }
    if !r.sectors.s2 {
        blanks.push("s2");
    }
    if !r.sectors.s3 {
        blanks.push("s3");
    }
    if blanks.is_empty() {
        None
    } else {
        Some(format!("blank: {}", blanks.join(",")))
    }
}

fn check_elapsed_accumulation(records: &[LapRecord], report: &mut ValidationReport) {
    for (_, laps) in group_by_car(records) {
        let mut sorted = laps;
        sorted.sort_by_key(|r| r.lap.lap_number);

        let mut running: u64 = 0;
        for r in sorted {
            running = running.saturating_add(u64::from(r.lap.time));
            let actual = u64::from(r.lap.elapsed);
            if running != actual {
                report.issues.push(Issue {
                    kind: IssueKind::ElapsedDrift,
                    car_number: r.lap.car_number.clone(),
                    lap_number: r.lap.lap_number,
                    expected_ms: running as i64,
                    actual_ms: actual as i64,
                    note: None,
                });
            }
        }
    }
}

fn check_hour_elapsed_correspondence(records: &[LapRecord], report: &mut ValidationReport) {
    let mut reference: Option<i64> = None;

    for r in records {
        let hour_str = r.stats.hour.trim();
        if hour_str.is_empty() {
            report.issues.push(Issue {
                kind: IssueKind::HourUnparseable,
                car_number: r.lap.car_number.clone(),
                lap_number: r.lap.lap_number,
                expected_ms: 0,
                actual_ms: 0,
                note: Some("empty hour".to_string()),
            });
            continue;
        }
        let Some(hour_ms) = duration::from_string(hour_str) else {
            report.issues.push(Issue {
                kind: IssueKind::HourUnparseable,
                car_number: r.lap.car_number.clone(),
                lap_number: r.lap.lap_number,
                expected_ms: 0,
                actual_ms: 0,
                note: Some(format!("unparseable hour: '{hour_str}'")),
            });
            continue;
        };

        let offset = (i64::from(hour_ms) - i64::from(r.lap.elapsed)).rem_euclid(DAY_MS);
        match reference {
            None => reference = Some(offset),
            Some(expected) if expected != offset => {
                report.issues.push(Issue {
                    kind: IssueKind::HourOffset,
                    car_number: r.lap.car_number.clone(),
                    lap_number: r.lap.lap_number,
                    expected_ms: expected,
                    actual_ms: offset,
                    note: None,
                });
            }
            _ => {}
        }
    }
}

/// Groups laps by car number, preserving CSV first-seen order so reports
/// match the ordering humans see in the source file.
fn group_by_car(records: &[LapRecord]) -> Vec<(&str, Vec<&LapRecord>)> {
    let mut order: Vec<&str> = Vec::new();
    let mut groups: Vec<Vec<&LapRecord>> = Vec::new();

    for r in records {
        let key = r.lap.car_number.as_str();
        match order.iter().position(|n| *n == key) {
            Some(idx) => groups[idx].push(r),
            None => {
                order.push(key);
                groups.push(vec![r]);
            }
        }
    }

    order.into_iter().zip(groups).collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{CarInfo, LapStats, ParsedLap, SectorPresence};

    fn record(
        car_number: &str,
        lap_number: u32,
        time: u32,
        s1: u32,
        s2: u32,
        s3: u32,
        elapsed: u32,
        hour: &str,
        sectors: SectorPresence,
    ) -> LapRecord {
        LapRecord {
            lap: ParsedLap {
                car_number: car_number.to_string(),
                driver: "Driver".to_string(),
                lap_number,
                time,
                sector_1: s1,
                sector_2: s2,
                sector_3: s3,
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
                hour: hour.to_string(),
                top_speed: None,
                pit_time: None,
            },
            sectors,
            mini_sectors: None,
        }
    }

    fn all_present() -> SectorPresence {
        SectorPresence {
            s1: true,
            s2: true,
            s3: true,
        }
    }

    #[test]
    fn validate_returns_clean_for_empty_records() {
        let report = validate(&[]);
        assert!(report.is_clean());
    }

    #[test]
    fn sector_sum_passes_for_consistent_data() {
        let r = record(
            "12",
            1,
            95365,
            23155,
            29928,
            42282,
            95365,
            "11:02:02.856",
            all_present(),
        );
        let report = validate(&[r]);
        assert!(
            report
                .issues
                .iter()
                .all(|i| i.kind != IssueKind::SectorSum)
        );
    }

    #[test]
    fn sector_sum_detects_mismatch() {
        let r = record(
            "12",
            1,
            95365,
            23155,
            29928,
            42283, // off by 1 ms
            95365,
            "11:02:02.856",
            all_present(),
        );
        let report = validate(&[r]);
        let issue = report
            .issues
            .iter()
            .find(|i| i.kind == IssueKind::SectorSum)
            .expect("should have a sector-sum issue");
        assert_eq!(issue.car_number, "12");
        assert_eq!(issue.lap_number, 1);
        assert_eq!(issue.expected_ms, 95365);
        assert_eq!(issue.actual_ms, 95366);
        assert!(issue.note.is_none());
    }

    #[test]
    fn sector_sum_flags_blank_sector_with_note() {
        let r = record(
            "12",
            1,
            95365,
            0, // blank S1 → 0
            29928,
            42282,
            95365,
            "11:02:02.856",
            SectorPresence {
                s1: false,
                s2: true,
                s3: true,
            },
        );
        let report = validate(&[r]);
        let issue = report
            .issues
            .iter()
            .find(|i| i.kind == IssueKind::SectorSum)
            .expect("should have a sector-sum issue");
        assert_eq!(issue.note.as_deref(), Some("blank: s1"));
    }

    #[test]
    fn elapsed_accumulation_passes_for_consistent_data() {
        let records = vec![
            record(
                "12",
                1,
                95365,
                23155,
                29928,
                42282,
                95365,
                "11:02:02.856",
                all_present(),
            ),
            record(
                "12",
                2,
                113610,
                26770,
                29296,
                57544,
                208975,
                "11:03:56.466",
                all_present(),
            ),
        ];
        let report = validate(&records);
        assert!(
            report
                .issues
                .iter()
                .all(|i| i.kind != IssueKind::ElapsedDrift)
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
                23155,
                29928,
                42282,
                95365,
                "11:02:02.856",
                all_present(),
            ),
            record(
                "A",
                2,
                113610,
                26770,
                29296,
                57544,
                208975,
                "11:03:56.466",
                all_present(),
            ),
            // Car B: lap 2 elapsed off by 100 ms.
            record(
                "B",
                1,
                95365,
                23155,
                29928,
                42282,
                95365,
                "11:02:02.856",
                all_present(),
            ),
            record(
                "B",
                2,
                113610,
                26770,
                29296,
                57544,
                209075, // expected 208975
                "11:03:56.566",
                all_present(),
            ),
        ];
        let report = validate(&records);
        let drift_issues: Vec<&Issue> = report
            .issues
            .iter()
            .filter(|i| i.kind == IssueKind::ElapsedDrift)
            .collect();
        assert_eq!(drift_issues.len(), 1);
        assert_eq!(drift_issues[0].car_number, "B");
        assert_eq!(drift_issues[0].lap_number, 2);
        assert_eq!(drift_issues[0].expected_ms, 208975);
        assert_eq!(drift_issues[0].actual_ms, 209075);
    }

    #[test]
    fn hour_elapsed_correspondence_clean_for_constant_offset() {
        // Race starts at 11:00:27.491. Both cars share the same offset.
        let records = vec![
            record(
                "12",
                1,
                95365,
                23155,
                29928,
                42282,
                95365,
                "11:02:02.856",
                all_present(),
            ),
            record(
                "7",
                1,
                95421,
                23277,
                29848,
                42296,
                95421,
                "11:02:02.912",
                all_present(),
            ),
        ];
        let report = validate(&records);
        assert!(
            report
                .issues
                .iter()
                .all(|i| i.kind != IssueKind::HourOffset)
        );
    }

    #[test]
    fn hour_elapsed_correspondence_handles_midnight_wrap() {
        // Race start 16:00:00.000. Lap 1 ends at 16:01:35.365.
        // Hours later, elapsed crosses 8h, hour wraps to 00:00:00.
        // Reference offset = 16h. After 8h elapsed, hour=00:00:00 →
        // (0 - 8h) mod 24h = 16h. Same offset.
        let records = vec![
            record(
                "12",
                1,
                95365,
                23155,
                29928,
                42282,
                95365,
                "16:01:35.365",
                all_present(),
            ),
            record(
                "12",
                2,
                28_704_635, // lap-2 time (irrelevant for hour check; elapsed matters)
                0,
                0,
                0,
                28_800_000, // 8h elapsed
                "00:00:00.000",
                all_present(),
            ),
        ];
        let report = validate(&records);
        assert!(
            report
                .issues
                .iter()
                .all(|i| i.kind != IssueKind::HourOffset),
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
                23155,
                29928,
                42282,
                95365,
                "11:02:02.856",
                all_present(),
            ),
            record(
                "12",
                2,
                113610,
                26770,
                29296,
                57544,
                208975,
                "11:03:56.566", // 100 ms late vs reference
                all_present(),
            ),
        ];
        let report = validate(&records);
        let issue = report
            .issues
            .iter()
            .find(|i| i.kind == IssueKind::HourOffset)
            .expect("should detect hour-offset drift");
        assert_eq!(issue.car_number, "12");
        assert_eq!(issue.lap_number, 2);
        assert_eq!(issue.actual_ms - issue.expected_ms, 100);
    }

    #[test]
    fn hour_unparseable_string_reported() {
        let records = vec![
            record(
                "12",
                1,
                95365,
                23155,
                29928,
                42282,
                95365,
                "", // empty
                all_present(),
            ),
            record(
                "12",
                2,
                113610,
                26770,
                29296,
                57544,
                208975,
                "not-a-time",
                all_present(),
            ),
        ];
        let report = validate(&records);
        let unparseable: Vec<&Issue> = report
            .issues
            .iter()
            .filter(|i| i.kind == IssueKind::HourUnparseable)
            .collect();
        assert_eq!(unparseable.len(), 2);
    }
}
