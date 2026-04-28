//! Intermediate domain types that flow through the pipeline.
//!
//! - `LapRecord`: a full lap description (`ParsedLap` + auxiliary data)
//! - `ParsedLap`: the core lap fields after lexical conversion
//! - `CarInfo`: per-car metadata shared across every lap
//! - `LapStats`: extra metrics that only come from the CSV
//! - `SectorPresence`: flags for whether CSV S1/S2/S3 cells were non-empty

use motorsport::Duration;

#[derive(Debug, Clone)]
pub struct LapRecord {
    pub lap: ParsedLap,
    pub car: CarInfo,
    pub stats: LapStats,
    pub sectors: SectorPresence,
}

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
/// `motorsport::Duration` (`u32`) cannot distinguish a blank cell from a
/// legitimate 0 ms. We preserve that distinction here so the JSON output can
/// keep blank cells blank.
#[derive(Debug, Clone, Copy)]
pub struct SectorPresence {
    pub s1: bool,
    pub s2: bool,
    pub s3: bool,
}
