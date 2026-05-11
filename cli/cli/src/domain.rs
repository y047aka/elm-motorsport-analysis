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
use motorsport::{HourClock, MiniSectorId};

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
    /// Speed in km/h as the raw CSV string (e.g. `"175.0"`, `"160.7"`).
    /// Kept as-is so the output JSON preserves the input's decimal format
    /// exactly, matching the Flix implementation.
    pub kph: String,
    pub flag_at_fl: String,
    /// Wall-clock time of day for this lap crossing. `None` when the HOUR
    /// cell was missing or unparseable; the validation stage skips such rows
    /// in the `HourElapsedOffset` race-wide check to avoid cascading false
    /// positives.
    pub hour: Option<HourClock>,
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
    fn has_content(&self) -> bool {
        is_meaningful(&self.time) || is_meaningful(&self.elapsed)
    }

    /// Returns `Some(ms)` only when the time cell is non-blank and parseable.
    /// Used by the validation stage to distinguish "zero" from "absent".
    pub fn parse_time_opt(&self) -> Option<Duration> {
        self.time
            .as_deref()
            .filter(|s| !s.trim().is_empty())
            .and_then(duration::from_string)
    }

    /// Returns `Some(ms)` only when the elapsed cell is non-blank and parseable.
    pub fn parse_elapsed_opt(&self) -> Option<Duration> {
        self.elapsed
            .as_deref()
            .filter(|s| !s.trim().is_empty())
            .and_then(duration::from_string)
    }
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

impl MiniSectorTimes {
    /// Returns all 15 entries in track order, paired with their `MiniSectorId`.
    ///
    /// Used by the validation stage to walk sectors in track order without
    /// duplicating the ordering logic.
    pub fn as_ordered_pairs(&self) -> [(MiniSectorId, &MiniSectorEntry); 15] {
        use MiniSectorId::*;
        [
            (Scl2,   &self.scl2),
            (Z4,     &self.z4),
            (Ip1,    &self.ip1),
            (Z12,    &self.z12),
            (Sclc,   &self.sclc),
            (A7_1,   &self.a7_1),
            (Ip2,    &self.ip2),
            (A8_1,   &self.a8_1),
            (Sclb,   &self.sclb),
            (Porin,  &self.porin),
            (Porout, &self.porout),
            (Pitref, &self.pitref),
            (Scl1,   &self.scl1),
            (Fordout,&self.fordout),
            (Fl,     &self.fl),
        ]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// `MiniSectorTimes::as_ordered_pairs` and `MiniSectorId::all` are two
    /// independent declarations of the 15-sector track-order list. If anyone
    /// adds a 16th sector they must update both — this test guards the pair
    /// so the discrepancy fails fast instead of silently dropping a sector
    /// from validation.
    #[test]
    fn as_ordered_pairs_matches_mini_sector_id_all() {
        let times = MiniSectorTimes::default();
        let pairs = times.as_ordered_pairs();
        let all = MiniSectorId::all();
        assert_eq!(pairs.len(), all.len(), "sector count drifted");
        for (i, (id, _)) in pairs.iter().enumerate() {
            assert_eq!(*id, all[i], "sector order drifted at index {i}");
        }
    }

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

}
