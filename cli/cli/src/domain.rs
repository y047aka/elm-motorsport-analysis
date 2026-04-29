//! Intermediate domain types that flow through the pipeline.
//!
//! The vocabulary used between CSV input and JSON output, split by role:
//!
//! - `LapRecord`: a full lap description (`ParsedLap` + auxiliary data)
//! - `ParsedLap`: the core lap fields after lexical conversion (no bests yet)
//! - `CarInfo`: per-car metadata shared across every lap
//! - `LapStats`: extra metrics that only come from the CSV
//! - `Hour`: wall-clock time-of-day, ms-since-midnight
//!
//! Sector cells (`ParsedLap.sector_{1,2,3}`) and the hour stat both use
//! `Result<T, String>`: `Ok` is the parsed value, `Err` carries the raw CSV
//! input (empty string, whitespace, or unparseable text) so output can
//! round-trip it and validation can report what was there.
//! - `MiniSectorTimes` / `MiniSectorEntry`: 15-sector Le Mans 24h data
//! - `BestTimes` / `MiniSectorBests`: accumulators updated during a car's laps

use std::fmt;

use motorsport::duration::{self, Duration};

/// One day in milliseconds. `Hour` values are kept folded into `[0, DAY_MS)`.
pub const DAY_MS: u32 = 86_400_000;

/// Single source of the 15 mini-sector identifiers shared by `MiniSectorTimes`,
/// `MiniSectorBests`, and `transform::build_mini_sectors`.
///
/// Passes 15 mini-sector names as Rust identifiers to the given macro `$m`.
///
/// Not covered (requires CSV-side concatenation, which stable Rust can't do
/// without an external crate like `paste`):
/// - the 30 `#[serde(rename = ...)]` attributes on `stages::csv_input::CsvRow`
///   (names like `A7-1_time` include a dash, so a straight uppercase rule
///   wouldn't produce them)
/// - the `MiniSectorEntry { time: row.scl2_time, elapsed: row.scl2_elapsed }`
///   wiring in `stages::structure::lap_record_from`
///
/// Adding a 16th sector therefore requires editing this macro plus those two
/// sites by hand.
macro_rules! with_mini_sector_names {
    ($m:ident) => {
        $m! {
            scl2, z4, ip1, z12, sclc,
            a7_1, ip2, a8_1, sclb, porin,
            porout, pitref, scl1, fordout, fl
        }
    };
}
pub(crate) use with_mini_sector_names;

#[derive(Debug, Clone)]
pub struct LapRecord {
    pub lap: ParsedLap,
    pub car: CarInfo,
    pub stats: LapStats,
    pub mini_sectors: Option<MiniSectorTimes>,
}

/// Lap fields after lexical conversion, before per-car best-time accumulation.
///
/// `transform::process_laps` consumes this to construct the final
/// `motorsport::Lap` with real bests filled in.
#[derive(Debug, Clone)]
pub struct ParsedLap {
    pub car_number: String,
    pub driver: String,
    pub lap_number: u32,
    pub time: Duration,
    /// `Ok(d)` is a successfully parsed sector duration. `Err(raw)` preserves
    /// the original CSV cell (empty string for blank cells, raw text for
    /// unparseable cells) so it can round-trip to JSON output and be reported
    /// by validation.
    pub sector_1: Result<Duration, String>,
    pub sector_2: Result<Duration, String>,
    pub sector_3: Result<Duration, String>,
    pub elapsed: Duration,
}

#[derive(Debug, Clone)]
pub struct CarInfo {
    pub class: String,
    pub group: String,
    pub team: String,
    pub manufacturer: String,
}

#[derive(Debug, Clone)]
pub struct LapStats {
    pub driver_number: u32,
    pub lap_improvement: i32,
    pub crossing_finish_line_in_pit: String,
    pub s1_improvement: i32,
    pub s2_improvement: i32,
    pub s3_improvement: i32,
    pub kph: f32,
    /// Parsed wall-clock time-of-day. `Err` carries the original raw CSV
    /// value (empty string for blank cells) so it can round-trip to JSON
    /// output and be reported by validation.
    pub hour: Result<Hour, String>,
    pub top_speed: Option<String>,
    pub pit_time: Option<Duration>,
}

/// Reads a sector cell as a duration, treating blank or unparseable cells as
/// 0 ms. Used by transform and validation when summing or comparing sectors;
/// `output` keeps the `Result` form to round-trip the original CSV value.
pub fn sector_duration(s: &Result<Duration, String>) -> Duration {
    s.as_ref().copied().unwrap_or(0)
}

/// Wall-clock time-of-day, stored as milliseconds since midnight.
///
/// The CLI never crosses a date boundary inside a single CSV (24h races wrap
/// once, which the `validation` module folds via mod 24h). A bare ms-since-
/// midnight value is therefore enough — no chrono dependency needed for what
/// is essentially a duration-since-midnight.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Hour(u32);

impl Hour {
    /// Parses an `H:MM:SS.mmm` cell. Anything else (empty, two-component, or
    /// 24h or more) becomes `Err(raw.to_string())` so the original input is
    /// preserved for output and validation reporting.
    pub fn parse(raw: &str) -> Result<Self, String> {
        let trimmed = raw.trim();
        // Hour-of-day must have three components — otherwise "11:02" would
        // silently parse as 11 minutes 2 seconds.
        if trimmed.split(':').count() != 3 {
            return Err(raw.to_string());
        }
        match duration::from_string(trimmed) {
            Some(ms) if ms < DAY_MS => Ok(Hour(ms)),
            _ => Err(raw.to_string()),
        }
    }

    pub fn ms_since_midnight(self) -> u32 {
        self.0
    }

    /// `(self - elapsed) mod 24h`. Used by validation to check the race-start
    /// invariant across midnight wrap.
    pub fn offset_from(self, elapsed: Duration) -> u32 {
        (i64::from(self.0) - i64::from(elapsed)).rem_euclid(i64::from(DAY_MS)) as u32
    }
}

impl fmt::Display for Hour {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&duration::to_string(self.0))
    }
}

#[derive(Debug, Clone, Default)]
pub struct MiniSectorEntry {
    pub time: Option<String>,
    pub elapsed: Option<String>,
}

impl MiniSectorEntry {
    pub fn parse_time(&self) -> Duration {
        parse_opt(&self.time)
    }

    pub fn parse_elapsed(&self) -> Duration {
        parse_opt(&self.elapsed)
    }

    fn has_content(&self) -> bool {
        is_meaningful(&self.time) || is_meaningful(&self.elapsed)
    }
}

fn parse_opt(value: &Option<String>) -> Duration {
    value
        .as_ref()
        .and_then(|s| duration::from_string(s))
        .unwrap_or(0)
}

fn is_meaningful(value: &Option<String>) -> bool {
    value.as_ref().is_some_and(|s| !s.trim().is_empty())
}

macro_rules! define_mini_sector_times {
    ($($name:ident),* $(,)?) => {
        /// All 15 Le Mans 24h mini-sectors.
        #[derive(Debug, Clone, Default)]
        pub struct MiniSectorTimes {
            $(pub $name: MiniSectorEntry,)*
        }

        impl MiniSectorTimes {
            /// Collapses to `None` if every entry is blank (for events that
            /// don't provide mini-sector columns).
            pub fn into_optional(self) -> Option<Self> {
                if self.has_any() { Some(self) } else { None }
            }

            fn has_any(&self) -> bool {
                false $(|| self.$name.has_content())*
            }
        }
    };
}
with_mini_sector_names!(define_mini_sector_times);

/// Accumulator updated as laps are processed for a single car.
#[derive(Debug, Clone, Default)]
pub struct BestTimes {
    pub lap: Option<Duration>,
    pub s1: Option<Duration>,
    pub s2: Option<Duration>,
    pub s3: Option<Duration>,
    pub mini: MiniSectorBests,
}

impl BestTimes {
    /// Updates lap / S1 / S2 / S3 bests. Zero values are ignored (a zero
    /// typically means "blank CSV cell", not an actual zero-duration lap).
    pub fn update_lap_and_sectors(
        &mut self,
        lap: Duration,
        s1: Duration,
        s2: Duration,
        s3: Duration,
    ) {
        self.lap = best(self.lap, lap);
        self.s1 = best(self.s1, s1);
        self.s2 = best(self.s2, s2);
        self.s3 = best(self.s3, s3);
    }

    pub fn update_mini(&mut self, mini: &MiniSectorTimes) {
        self.mini.update_from(mini);
    }
}

macro_rules! define_mini_sector_bests {
    ($($name:ident),* $(,)?) => {
        #[derive(Debug, Clone, Default)]
        pub struct MiniSectorBests {
            $(pub $name: Option<Duration>,)*
        }

        impl MiniSectorBests {
            fn update_from(&mut self, mini: &MiniSectorTimes) {
                $(self.$name = best(self.$name, mini.$name.parse_time());)*
            }
        }
    };
}
with_mini_sector_names!(define_mini_sector_bests);

fn best(current_best: Option<Duration>, candidate: Duration) -> Option<Duration> {
    if candidate == 0 {
        current_best
    } else {
        Some(current_best.map_or(candidate, |b| b.min(candidate)))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mini_sector_times_default_collapses_to_none() {
        assert!(MiniSectorTimes::default().into_optional().is_none());
    }

    #[test]
    fn mini_sector_times_with_whitespace_only_entries_collapses_to_none() {
        let times = MiniSectorTimes {
            scl2: MiniSectorEntry {
                time: Some("   ".to_string()),
                elapsed: Some("\t".to_string()),
            },
            ..Default::default()
        };
        assert!(times.into_optional().is_none());
    }

    #[test]
    fn mini_sector_times_with_any_meaningful_entry_is_retained() {
        let times = MiniSectorTimes {
            fl: MiniSectorEntry {
                time: Some("8.112".to_string()),
                elapsed: None,
            },
            ..Default::default()
        };
        let retained = times.into_optional().expect("should be retained");
        assert_eq!(retained.fl.time.as_deref(), Some("8.112"));
    }

    #[test]
    fn best_times_update_with_all_zero_leaves_state_untouched() {
        let mut bests = BestTimes::default();
        bests.update_lap_and_sectors(100_000, 30_000, 30_000, 40_000);
        let snapshot = bests.clone();

        bests.update_lap_and_sectors(0, 0, 0, 0);

        assert_eq!(bests.lap, snapshot.lap);
        assert_eq!(bests.s1, snapshot.s1);
        assert_eq!(bests.s2, snapshot.s2);
        assert_eq!(bests.s3, snapshot.s3);
    }

    #[test]
    fn best_times_update_keeps_the_minimum() {
        let mut bests = BestTimes::default();
        bests.update_lap_and_sectors(100_000, 30_000, 30_000, 40_000);
        bests.update_lap_and_sectors(95_000, 35_000, 29_000, 40_000);

        assert_eq!(bests.lap, Some(95_000));
        assert_eq!(bests.s1, Some(30_000));
        assert_eq!(bests.s2, Some(29_000));
        assert_eq!(bests.s3, Some(40_000));
    }

    #[test]
    fn best_times_mini_update_skips_zero_sectors() {
        let mut bests = BestTimes::default();

        let all_zeros = MiniSectorTimes::default();
        bests.update_mini(&all_zeros);
        assert_eq!(bests.mini.scl2, None);
        assert_eq!(bests.mini.fl, None);

        let only_fl = MiniSectorTimes {
            fl: MiniSectorEntry {
                time: Some("8.112".to_string()),
                elapsed: None,
            },
            ..Default::default()
        };
        bests.update_mini(&only_fl);
        assert_eq!(bests.mini.scl2, None);
        assert_eq!(bests.mini.fl, Some(8_112));
    }
}
