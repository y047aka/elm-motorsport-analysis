//! Source-data integrity checks run after structuring, before transform.
//!
//! All rules use strict 0 ms equality. Violations are returned as warnings
//! only; they do not affect the exit code. `process_file` prints them to
//! stderr.
//!
//! Rules:
//!   1. SectorSum                  — `s1 + s2 + s3 == lapTime` (per row)
//!   2. ElapsedDrift               — per car, `elapsed[n] == sum(lapTime[1..=n])`
//!                                   (cumulative-sum: every row from the first drift
//!                                   onward is reported)
//!   3. HourElapsedOffset          — across the CSV, `(hour - elapsed) mod 24h` is
//!                                   constant
//!   4. MiniSectorSum              — when mini-sectors present, `sum(time) == lapTime`
//!                                   (blank `time` counted as zero).
//!                                   Skipped on pit laps and Ford-chicane track-limits
//!                                   signatures.
//!   5. MiniSectorElapsedMonotonic — when mini-sectors present, `elapsed` values are
//!                                   strictly increasing in track order.
//!
//! Design notes:
//!   - `HourElapsedOffset` baseline is the **first row with a parseable hour cell**
//!     in the whole CSV (race-wide, not per-car). Rows whose HOUR was missing or
//!     unparseable are skipped — they can no longer cascade false positives across
//!     the rest of the race.
//!   - 24 h wrap is handled by `HourClock::offset_from`, so the validator just
//!     compares offsets with `==`.
//!   - Report order follows CSV appearance (per-lap rules: natural CSV order;
//!     per-car rules: first-seen index to sort car groups).
//!   - Mini-sector rules silently skip laps where `mini_sectors == None`.
//!   - **MiniSectorSum pit-lap skip** — pit-entry laps bypass main-line markers
//!     (typically FORDOUT and FL_time) so the sum can never reach lapTime.
//!     Identified by `crossing_finish_line_in_pit == "B"` or `pit_time != None`.
//!   - **MiniSectorSum track-limits skip** — running off the Ford chicanes leaves a
//!     known blank pattern (SCL1+FORDOUT for the second chicane, PITREF+SCL1 for
//!     the first). These are the dominant non-pit cause of sum mismatches.

use std::collections::HashMap;

use motorsport::duration;
use motorsport::mini_sector::is_track_limits_signature;
use motorsport::MiniSectorId;

use crate::domain::{LapRecord, MiniSectorTimes};

// ================================================================
// Public API
// ================================================================

/// Returns formatted warning lines (one per violation) for all integrity
/// issues found in `records`. Meant to be printed to stderr by the caller.
///
/// The `event_name` is prepended to every line so multi-file runs stay
/// distinguishable.
pub fn validate(event_name: &str, records: &[LapRecord]) -> Vec<String> {
    detect(records)
        .into_iter()
        .map(|v| format_violation(event_name, &v))
        .collect()
}

// ================================================================
// Violation types
// ================================================================

#[derive(Debug)]
enum Violation<'a> {
    /// `s1 + s2 + s3 != lapTime`.
    /// Fields: lap record / lapTime / sector sum / labels of blank sectors.
    SectorSum(&'a LapRecord, u32, u32, Vec<&'static str>),

    /// `elapsed[n] != sum(lapTime[1..=n])`. Sticky: every row from the first
    /// drift onward is reported.
    /// Fields: lap record / expected (running sum) / actual (elapsed).
    ElapsedDrift(&'a LapRecord, u32, u32),

    /// `(hour - elapsed) mod 24h` does not match the CSV-wide baseline.
    /// Fields: lap record / baseline offset ms / actual offset ms.
    HourElapsedOffset(&'a LapRecord, u32, u32),

    /// `sum(miniSector.time) != lapTime`.
    /// Fields: lap record / lapTime / sum / IDs of sectors with blank time.
    MiniSectorSum(&'a LapRecord, u32, u32, Vec<MiniSectorId>),

    /// Mini-sector `elapsed[i] <= elapsed[i-1]` for some adjacent pair.
    /// Fields: lap record / prev id / prev elapsed / curr id / curr elapsed.
    MiniSectorElapsedMonotonic(&'a LapRecord, MiniSectorId, u32, MiniSectorId, u32),
}

// ================================================================
// Detection
// ================================================================

fn detect<'a>(records: &'a [LapRecord]) -> Vec<Violation<'a>> {
    let per_lap = records
        .iter()
        .filter_map(check_sector_sum)
        .collect::<Vec<_>>();

    let per_car = per_car_violations(records);
    let per_race = check_hour_elapsed_race_wide(records);
    let per_mini = records.iter().flat_map(check_mini_sectors).collect::<Vec<_>>();

    [per_lap, per_car, per_race, per_mini].into_iter().flatten().collect()
}

// ── Rule 1: SectorSum ────────────────────────────────────────────────────────

fn check_sector_sum(record: &LapRecord) -> Option<Violation<'_>> {
    let lap_time = record.lap.time;
    let (s1, s1_blank) = sector_or_zero(record.lap.sector_1, record.sectors.s1, "s1");
    let (s2, s2_blank) = sector_or_zero(record.lap.sector_2, record.sectors.s2, "s2");
    let (s3, s3_blank) = sector_or_zero(record.lap.sector_3, record.sectors.s3, "s3");
    let sum = s1 + s2 + s3;

    if sum == lap_time {
        None
    } else {
        let blanks: Vec<&'static str> = [s1_blank, s2_blank, s3_blank]
            .into_iter()
            .flatten()
            .collect();
        Some(Violation::SectorSum(record, lap_time, sum, blanks))
    }
}

/// Returns `(duration_ms, blank_label_if_cell_was_empty)`.
fn sector_or_zero(duration: u32, present: bool, label: &'static str) -> (u32, Option<&'static str>) {
    if present {
        (duration, None)
    } else {
        (0, Some(label))
    }
}

// ── Rule 2: ElapsedDrift ─────────────────────────────────────────────────────

fn per_car_violations<'a>(records: &'a [LapRecord]) -> Vec<Violation<'a>> {
    // Group by car_number, preserving first-seen CSV order.
    let mut first_seen: HashMap<&str, usize> = HashMap::new();
    let mut grouped: HashMap<&str, Vec<&'a LapRecord>> = HashMap::new();

    for (index, record) in records.iter().enumerate() {
        let car = record.lap.car_number.as_str();
        first_seen.entry(car).or_insert(index);
        grouped.entry(car).or_default().push(record);
    }

    // Sort car groups by first-seen index, then check each car's laps.
    let mut car_order: Vec<(&str, Vec<&LapRecord>)> = grouped.into_iter().collect();
    car_order.sort_by_key(|(car, _)| first_seen[*car]);

    car_order
        .into_iter()
        .flat_map(|(_, mut car_laps)| {
            car_laps.sort_by_key(|r| r.lap.lap_number);
            check_elapsed_drift(&car_laps)
        })
        .collect()
}

fn check_elapsed_drift<'a>(sorted_laps: &[&'a LapRecord]) -> Vec<Violation<'a>> {
    let mut running: u32 = 0;
    let mut violations = Vec::new();

    for record in sorted_laps {
        running = running.saturating_add(record.lap.time);
        let elapsed = record.lap.elapsed;
        if running != elapsed {
            violations.push(Violation::ElapsedDrift(record, running, elapsed));
        }
    }

    violations
}

// ── Rule 3: HourElapsedOffset ────────────────────────────────────────────────

/// Race-wide hour-vs-elapsed offset check.
///
/// Baseline is the **first row with a parseable `hour` cell** (not necessarily
/// the first record in the CSV). Rows whose `hour` failed to parse are silently
/// skipped — a single malformed cell can therefore no longer poison the
/// baseline or cascade through the rest of the race.
fn check_hour_elapsed_race_wide<'a>(records: &'a [LapRecord]) -> Vec<Violation<'a>> {
    let mut baseline: Option<u32> = None;
    let mut violations = Vec::new();

    for record in records {
        let Some(hour) = record.stats.hour else {
            continue;
        };
        let offset = hour.offset_from(record.lap.elapsed);
        match baseline {
            None => baseline = Some(offset),
            Some(base) if offset != base => {
                violations.push(Violation::HourElapsedOffset(record, base, offset));
            }
            _ => {}
        }
    }

    violations
}

// ── Rules 4 & 5: MiniSector checks ──────────────────────────────────────────

fn check_mini_sectors(record: &LapRecord) -> Vec<Violation<'_>> {
    let Some(mini) = &record.mini_sectors else {
        return vec![];
    };

    let sum_viols = if is_pit_lap(record) {
        vec![]
    } else {
        check_mini_sector_sum(record, mini)
    };

    let mono_viols = check_mini_sector_monotonic(record, mini);

    [sum_viols, mono_viols].into_iter().flatten().collect()
}

fn is_pit_lap(record: &LapRecord) -> bool {
    record.stats.crossing_finish_line_in_pit == "B" || record.stats.pit_time.is_some()
}

fn check_mini_sector_sum<'a>(record: &'a LapRecord, mini: &MiniSectorTimes) -> Vec<Violation<'a>> {
    let mut sum: u32 = 0;
    let mut blanks: Vec<MiniSectorId> = Vec::new();

    for (id, entry) in mini.as_ordered_pairs() {
        match entry.parse_time_opt() {
            Some(t) => sum = sum.saturating_add(t),
            None    => blanks.push(id),
        }
    }

    if sum == record.lap.time {
        return vec![];
    }
    if is_track_limits_signature(&blanks) {
        return vec![];
    }
    vec![Violation::MiniSectorSum(record, record.lap.time, sum, blanks)]
}

/// Reports each adjacent pair where the second elapsed is `<=` the first.
/// Blank-elapsed entries are skipped without breaking the chain.
fn check_mini_sector_monotonic<'a>(record: &'a LapRecord, mini: &MiniSectorTimes) -> Vec<Violation<'a>> {
    let mut prev: Option<(MiniSectorId, u32)> = None;
    let mut violations = Vec::new();

    for (id, entry) in mini.as_ordered_pairs() {
        let Some(curr_elapsed) = entry.parse_elapsed_opt() else {
            continue;
        };
        if let Some((prev_id, prev_elapsed)) = prev {
            if curr_elapsed <= prev_elapsed {
                violations.push(Violation::MiniSectorElapsedMonotonic(
                    record, prev_id, prev_elapsed, id, curr_elapsed,
                ));
            }
        }
        prev = Some((id, curr_elapsed));
    }

    violations
}

// ================================================================
// Formatting
// ================================================================

fn format_violation(event_name: &str, v: &Violation<'_>) -> String {
    match v {
        Violation::SectorSum(rec, lap_time, sum, blanks) => {
            let suffix = if blanks.is_empty() {
                String::new()
            } else {
                format!(" (blank: {})", blanks.join(","))
            };
            format!(
                "{}: [car {} #{}] sector-sum: expected={} ({}ms) actual={} ({}ms){}",
                event_name,
                rec.lap.car_number, rec.lap.lap_number,
                duration::to_string(*lap_time), lap_time,
                duration::to_string(*sum), sum,
                suffix,
            )
        }

        Violation::ElapsedDrift(rec, expected, actual) => format!(
            "{}: [car {} #{}] elapsed-drift: expected={} ({}ms) actual={} ({}ms)",
            event_name,
            rec.lap.car_number, rec.lap.lap_number,
            duration::to_string(*expected), expected,
            duration::to_string(*actual), actual,
        ),

        Violation::HourElapsedOffset(rec, base, offset) => format!(
            "{}: [car {} #{}] hour-offset: expected={} ({}ms) actual={} ({}ms)",
            event_name,
            rec.lap.car_number, rec.lap.lap_number,
            format_signed_ms(*base as i64), base,
            format_signed_ms(*offset as i64), offset,
        ),

        Violation::MiniSectorSum(rec, lap_time, sum, blanks) => {
            let suffix = if blanks.is_empty() {
                String::new()
            } else {
                let keys: Vec<&str> = blanks.iter().map(|id| id.json_key()).collect();
                format!(" (blank: {})", keys.join(","))
            };
            format!(
                "{}: [car {} #{}] mini-sector-sum: expected={} ({}ms) actual={} ({}ms){}",
                event_name,
                rec.lap.car_number, rec.lap.lap_number,
                duration::to_string(*lap_time), lap_time,
                duration::to_string(*sum), sum,
                suffix,
            )
        }

        Violation::MiniSectorElapsedMonotonic(rec, prev_id, prev_elapsed, curr_id, curr_elapsed) => {
            format!(
                "{}: [car {} #{}] mini-sector-elapsed[{}->{}]: prev={} ({}ms) curr={} ({}ms)",
                event_name,
                rec.lap.car_number, rec.lap.lap_number,
                prev_id.json_key(), curr_id.json_key(),
                duration::to_string(*prev_elapsed), prev_elapsed,
                duration::to_string(*curr_elapsed), curr_elapsed,
            )
        }
    }
}

fn format_signed_ms(ms: i64) -> String {
    if ms < 0 {
        format!("-{}", duration::to_string((-ms) as u32))
    } else {
        duration::to_string(ms as u32)
    }
}

// ================================================================
// Tests
// ================================================================

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{CarInfo, LapStats, MiniSectorEntry, MiniSectorTimes, ParsedLap, SectorPresence};
    use motorsport::HourClock;

    fn make_record(
        car: &str,
        lap_num: u32,
        time: u32,
        s1: u32,
        s2: u32,
        s3: u32,
        elapsed: u32,
    ) -> LapRecord {
        LapRecord {
            lap: ParsedLap {
                car_number: car.to_string(),
                driver: "Driver".to_string(),
                lap_number: lap_num,
                time,
                sector_1: s1,
                sector_2: s2,
                sector_3: s3,
                elapsed,
            },
            car: CarInfo {
                class: "HYPERCAR".to_string(),
                group: "H".to_string(),
                team: "Test Team".to_string(),
                manufacturer: "Test".to_string(),
            },
            stats: LapStats {
                driver_number: 1,
                lap_improvement: 0,
                crossing_finish_line_in_pit: String::new(),
                s1_improvement: 0,
                s2_improvement: 0,
                s3_improvement: 0,
                kph: 160.0,
                hour: HourClock::parse("11:00:00.000"),
                top_speed: None,
                pit_time: None,
            },
            sectors: SectorPresence { s1: s1 > 0, s2: s2 > 0, s3: s3 > 0 },
            mini_sectors: None,
        }
    }

    // ── Rule 1: SectorSum ─────────────────────────────────────────────────────

    #[test]
    fn sector_sum_clean() {
        // s1 + s2 + s3 == lapTime: no violation
        let rec = make_record("7", 1, 95_000, 23_000, 30_000, 42_000, 95_000);
        assert!(check_sector_sum(&rec).is_none());
    }

    #[test]
    fn sector_sum_mismatch_reports_violation() {
        // s1 + s2 + s3 = 94_000 != lapTime 95_000
        let rec = make_record("7", 1, 95_000, 23_000, 30_000, 41_000, 95_000);
        let v = check_sector_sum(&rec).expect("should detect mismatch");
        assert!(matches!(v, Violation::SectorSum(_, 95_000, 94_000, _)));
    }

    #[test]
    fn sector_sum_lists_blank_sectors() {
        // s2 is blank (present = false → duration = 0)
        let mut rec = make_record("7", 1, 95_000, 23_000, 30_000, 42_000, 95_000);
        rec.lap.sector_2 = 0;
        rec.sectors.s2 = false; // blank cell

        let v = check_sector_sum(&rec).expect("should detect mismatch");
        if let Violation::SectorSum(_, _, _, blanks) = v {
            assert!(blanks.contains(&"s2"));
        } else {
            panic!("wrong variant");
        }
    }

    // ── Rule 2: ElapsedDrift ──────────────────────────────────────────────────

    #[test]
    fn elapsed_drift_clean() {
        let records = vec![
            make_record("7", 1, 95_000, 23_000, 30_000, 42_000, 95_000),
            make_record("7", 2, 94_000, 23_000, 30_000, 41_000, 189_000),
        ];
        let refs: Vec<&LapRecord> = records.iter().collect();
        assert!(check_elapsed_drift(&refs).is_empty());
    }

    #[test]
    fn elapsed_drift_detects_sticky_drift() {
        // Lap 2 elapsed drifts by 1 ms; every subsequent lap also drifts.
        let records = vec![
            make_record("7", 1, 95_000, 23_000, 30_000, 42_000, 95_000),
            make_record("7", 2, 94_000, 23_000, 30_000, 41_000, 188_999), // 1 ms short
            make_record("7", 3, 93_000, 23_000, 30_000, 40_000, 281_999), // drift persists
        ];
        let refs: Vec<&LapRecord> = records.iter().collect();
        let viols = check_elapsed_drift(&refs);
        // Laps 2 and 3 should both be flagged.
        assert_eq!(viols.len(), 2);
    }

    // ── Rule 3: HourElapsedOffset ─────────────────────────────────────────────

    #[test]
    fn hour_elapsed_offset_consistent() {
        // Both laps: hour=11:00:00, race started at 11:00:00.
        // Lap 1 elapsed=1:35, offset = 11h - 1:35 = constant.
        // Lap 2 elapsed=3:10, hour=11:01:35 (start + 1:35 + run next lap).
        let mut r1 = make_record("7", 1, 95_000, 0, 0, 0, 95_000);
        r1.stats.hour = HourClock::parse("11:01:35.000");
        let mut r2 = make_record("7", 2, 95_000, 0, 0, 0, 190_000);
        r2.stats.hour = HourClock::parse("11:03:10.000");

        let records = vec![r1, r2];
        let viols = check_hour_elapsed_race_wide(&records);
        assert!(viols.is_empty(), "should be no violations: {viols:?}");
    }

    #[test]
    fn hour_elapsed_offset_mismatch_flagged() {
        let mut r1 = make_record("7", 1, 95_000, 0, 0, 0, 95_000);
        r1.stats.hour = HourClock::parse("11:01:35.000");
        // r2 hour is wrong — does not match expected offset.
        let mut r2 = make_record("7", 2, 95_000, 0, 0, 0, 190_000);
        r2.stats.hour = HourClock::parse("11:05:00.000"); // wrong

        let records = vec![r1, r2];
        let viols = check_hour_elapsed_race_wide(&records);
        assert_eq!(viols.len(), 1);
        assert!(matches!(viols[0], Violation::HourElapsedOffset(_, _, _)));
    }

    // ── Rule 4: MiniSectorSum ─────────────────────────────────────────────────

    #[test]
    fn mini_sector_sum_clean() {
        // Single-sector mini: fl=95s, lapTime=95s → no violation.
        let mut rec = make_record("7", 1, 95_000, 0, 0, 0, 95_000);
        let mut mini = MiniSectorTimes::default();
        mini.fl = MiniSectorEntry {
            time: Some("1:35.000".to_string()),
            elapsed: None,
        };
        rec.mini_sectors = Some(mini);
        let viols = check_mini_sector_sum(&rec, rec.mini_sectors.as_ref().unwrap());
        assert!(viols.is_empty());
    }

    #[test]
    fn mini_sector_sum_mismatch() {
        let mut rec = make_record("7", 1, 95_000, 0, 0, 0, 95_000);
        let mut mini = MiniSectorTimes::default();
        // fl = 90s but lapTime = 95s → mismatch
        mini.fl = MiniSectorEntry {
            time: Some("1:30.000".to_string()),
            elapsed: None,
        };
        rec.mini_sectors = Some(mini);
        let viols = check_mini_sector_sum(&rec, rec.mini_sectors.as_ref().unwrap());
        assert_eq!(viols.len(), 1);
    }

    #[test]
    fn mini_sector_sum_skips_track_limits_signature() {
        // lapTime = 95s, fl = 90s present, scl1+fordout both blank.
        // sum (90_000) != lapTime (95_000), but blanks == [Scl1, Fordout] →
        // matches the second-chicane track-limits signature and is skipped.
        let mut rec = make_record("7", 1, 95_000, 0, 0, 0, 95_000);
        let mut mini = MiniSectorTimes::default();
        // Fill every mini-sector except scl1 and fordout, so the blanks list
        // is exactly [Scl1, Fordout] in track order.
        for (id, _) in MiniSectorTimes::default().as_ordered_pairs() {
            if id == MiniSectorId::Scl1 || id == MiniSectorId::Fordout {
                continue;
            }
            let entry = MiniSectorEntry {
                // Per-sector time is irrelevant for the signature check —
                // only blank/non-blank pattern matters. Use small placeholder
                // values whose sum is < lapTime so a violation *would* fire
                // without the track-limits skip.
                time: Some("0:00.001".to_string()),
                elapsed: None,
            };
            match id {
                MiniSectorId::Scl2   => mini.scl2 = entry,
                MiniSectorId::Z4     => mini.z4 = entry,
                MiniSectorId::Ip1    => mini.ip1 = entry,
                MiniSectorId::Z12    => mini.z12 = entry,
                MiniSectorId::Sclc   => mini.sclc = entry,
                MiniSectorId::A7_1   => mini.a7_1 = entry,
                MiniSectorId::Ip2    => mini.ip2 = entry,
                MiniSectorId::A8_1   => mini.a8_1 = entry,
                MiniSectorId::Sclb   => mini.sclb = entry,
                MiniSectorId::Porin  => mini.porin = entry,
                MiniSectorId::Porout => mini.porout = entry,
                MiniSectorId::Pitref => mini.pitref = entry,
                MiniSectorId::Fl     => mini.fl = entry,
                MiniSectorId::Scl1 | MiniSectorId::Fordout => unreachable!(),
            }
        }
        rec.mini_sectors = Some(mini);

        // Sanity: sum != lapTime, so without the skip we'd flag a violation.
        let sum: u32 = rec
            .mini_sectors
            .as_ref()
            .unwrap()
            .as_ordered_pairs()
            .iter()
            .filter_map(|(_, e)| e.parse_time_opt())
            .sum();
        assert_ne!(sum, rec.lap.time, "test setup: sum must differ from lapTime");

        let viols = check_mini_sector_sum(&rec, rec.mini_sectors.as_ref().unwrap());
        assert!(viols.is_empty(), "track-limits signature must skip the violation");
    }

    #[test]
    fn mini_sector_sum_skips_pit_lap() {
        let mut rec = make_record("7", 1, 95_000, 0, 0, 0, 95_000);
        rec.stats.crossing_finish_line_in_pit = "B".to_string();
        let mut mini = MiniSectorTimes::default();
        // Sum would differ but pit laps are skipped.
        mini.fl = MiniSectorEntry { time: Some("1:30.000".to_string()), elapsed: None };
        rec.mini_sectors = Some(mini);
        let viols = check_mini_sectors(&rec);
        let sum_viols: Vec<_> = viols
            .iter()
            .filter(|v| matches!(v, Violation::MiniSectorSum(..)))
            .collect();
        assert!(sum_viols.is_empty(), "pit lap should skip MiniSectorSum");
    }

    // ── Rule 5: MiniSectorElapsedMonotonic ────────────────────────────────────

    #[test]
    fn mini_sector_elapsed_monotonic_clean() {
        let mut rec = make_record("7", 1, 95_000, 0, 0, 0, 95_000);
        let mut mini = MiniSectorTimes::default();
        mini.scl2 = MiniSectorEntry { time: None, elapsed: Some("8.000".to_string()) };
        mini.z4   = MiniSectorEntry { time: None, elapsed: Some("16.000".to_string()) };
        rec.mini_sectors = Some(mini);
        let viols = check_mini_sector_monotonic(&rec, rec.mini_sectors.as_ref().unwrap());
        assert!(viols.is_empty());
    }

    #[test]
    fn mini_sector_elapsed_not_monotonic_flagged() {
        let mut rec = make_record("7", 1, 95_000, 0, 0, 0, 95_000);
        let mut mini = MiniSectorTimes::default();
        mini.scl2 = MiniSectorEntry { time: None, elapsed: Some("16.000".to_string()) };
        mini.z4   = MiniSectorEntry { time: None, elapsed: Some("8.000".to_string()) }; // goes backwards
        rec.mini_sectors = Some(mini);
        let viols = check_mini_sector_monotonic(&rec, rec.mini_sectors.as_ref().unwrap());
        assert_eq!(viols.len(), 1);
        assert!(matches!(
            viols[0],
            Violation::MiniSectorElapsedMonotonic(_, MiniSectorId::Scl2, _, MiniSectorId::Z4, _)
        ));
    }

    // ── format_violation ─────────────────────────────────────────────────────

    #[test]
    fn format_violation_sector_sum_includes_blank_labels() {
        let rec = make_record("7", 3, 95_000, 23_000, 0, 42_000, 95_000);
        let v = Violation::SectorSum(&rec, 95_000, 65_000, vec!["s2"]);
        let s = format_violation("le_mans_24h", &v);
        assert!(s.contains("[car 7 #3]"));
        assert!(s.contains("sector-sum"));
        assert!(s.contains("(blank: s2)"));
    }

    #[test]
    fn validate_returns_empty_for_clean_data() {
        let records = vec![
            make_record("7", 1, 95_000, 23_000, 30_000, 42_000, 95_000),
        ];
        // hour offset: single row → baseline == itself, always clean.
        let warnings = validate("test", &records);
        assert!(warnings.is_empty(), "unexpected warnings: {warnings:?}");
    }
}
