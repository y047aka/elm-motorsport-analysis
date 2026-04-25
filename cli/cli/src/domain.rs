//! Intermediate domain types that flow through the pipeline.
//!
//! The vocabulary used between CSV input and JSON output, split by role:
//!
//! - `LapRecord`: a full lap description (`ParsedLap` + auxiliary data)
//! - `ParsedLap`: the core lap fields after lexical conversion (no bests yet)
//! - `CarInfo`: per-car metadata shared across every lap
//! - `LapStats`: extra metrics that only come from the CSV
//! - `SectorPresence`: flags for whether CSV S1/S2/S3 cells were non-empty
//! - `MiniSectorTimes` / `MiniSectorEntry`: 15-sector Le Mans 24h data
//! - `BestTimes` / `MiniSectorBests`: accumulators updated during a car's laps

use motorsport::duration::{self, Duration};

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
    pub sectors: SectorPresence,
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
    pub sector_1: Duration,
    pub sector_2: Duration,
    pub sector_3: Duration,
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
    pub hour: String,
    pub top_speed: Option<String>,
    pub pit_time: Option<Duration>,
}

/// Whether the CSV S1/S2/S3 columns were non-empty on a given row.
///
/// `motorsport::Lap::sector_{1,2,3}` is `Duration` (`u32`), so it cannot
/// distinguish a blank cell from a legitimate 0 ms. We preserve that
/// distinction here so the JSON output can keep blank cells blank.
#[derive(Debug, Clone, Copy)]
pub struct SectorPresence {
    pub s1: bool,
    pub s2: bool,
    pub s3: bool,
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
