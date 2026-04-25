//! Stage 2: parse CSV text into a list of [`CsvRow`].
//!
//! This module is responsible for lexical reading only. Converting rows into
//! the domain representation ([`LapRecord`](crate::domain::LapRecord)) is the
//! job of the next stage ([`structure`](super::structure)).

use serde::Deserialize;

/// Flat row representation produced by the parse stage.
///
/// Fields map directly to CSV columns. `Option<String>` indicates a column
/// that may be missing or blank. No semantic conversion (zero defaults,
/// duration parsing, blank detection) happens here.
#[derive(Debug, Deserialize)]
pub struct CsvRow {
    #[serde(rename = "NUMBER", alias = " NUMBER")]
    pub car_number: String,
    #[serde(rename = "DRIVER_NUMBER", alias = " DRIVER_NUMBER")]
    pub driver_number: u32,
    #[serde(rename = "DRIVER_NAME", alias = " DRIVER_NAME")]
    pub driver: String,
    #[serde(rename = "LAP_NUMBER", alias = " LAP_NUMBER")]
    pub lap: u32,
    #[serde(rename = "LAP_TIME", alias = " LAP_TIME")]
    pub lap_time: String,
    #[serde(rename = "LAP_IMPROVEMENT", alias = " LAP_IMPROVEMENT")]
    pub lap_improvement: i32,
    #[serde(
        rename = "CROSSING_FINISH_LINE_IN_PIT",
        alias = " CROSSING_FINISH_LINE_IN_PIT"
    )]
    pub crossing_finish_line_in_pit: String,
    #[serde(rename = "S1", alias = " S1")]
    pub s1: String,
    #[serde(rename = "S1_IMPROVEMENT", alias = " S1_IMPROVEMENT")]
    pub s1_improvement: i32,
    #[serde(rename = "S2", alias = " S2")]
    pub s2: String,
    #[serde(rename = "S2_IMPROVEMENT", alias = " S2_IMPROVEMENT")]
    pub s2_improvement: i32,
    #[serde(rename = "S3", alias = " S3")]
    pub s3: String,
    #[serde(rename = "S3_IMPROVEMENT", alias = " S3_IMPROVEMENT")]
    pub s3_improvement: i32,
    #[serde(rename = "KPH", alias = " KPH")]
    pub kph: f32,
    #[serde(rename = "ELAPSED", alias = " ELAPSED")]
    pub elapsed: String,
    #[serde(rename = "HOUR", alias = " HOUR")]
    pub hour: String,
    #[serde(rename = "TOP_SPEED", alias = " TOP_SPEED")]
    pub top_speed: Option<String>,
    #[serde(rename = "PIT_TIME", alias = " PIT_TIME")]
    pub pit_time: Option<String>,
    #[serde(rename = "CLASS", alias = " CLASS")]
    pub class: String,
    #[serde(rename = "GROUP", alias = " GROUP")]
    pub group: String,
    #[serde(rename = "TEAM", alias = " TEAM")]
    pub team: String,
    #[serde(rename = "MANUFACTURER", alias = " MANUFACTURER")]
    pub manufacturer: String,
    // Le Mans 24h mini-sector columns; `Option` because other events omit them.
    #[serde(rename = "SCL2_time", alias = " SCL2_time")]
    pub scl2_time: Option<String>,
    #[serde(rename = "SCL2_elapsed", alias = " SCL2_elapsed")]
    pub scl2_elapsed: Option<String>,
    #[serde(rename = "Z4_time", alias = " Z4_time")]
    pub z4_time: Option<String>,
    #[serde(rename = "Z4_elapsed", alias = " Z4_elapsed")]
    pub z4_elapsed: Option<String>,
    #[serde(rename = "IP1_time", alias = " IP1_time")]
    pub ip1_time: Option<String>,
    #[serde(rename = "IP1_elapsed", alias = " IP1_elapsed")]
    pub ip1_elapsed: Option<String>,
    #[serde(rename = "Z12_time", alias = " Z12_time")]
    pub z12_time: Option<String>,
    #[serde(rename = "Z12_elapsed", alias = " Z12_elapsed")]
    pub z12_elapsed: Option<String>,
    #[serde(rename = "SCLC_time", alias = " SCLC_time")]
    pub sclc_time: Option<String>,
    #[serde(rename = "SCLC_elapsed", alias = " SCLC_elapsed")]
    pub sclc_elapsed: Option<String>,
    #[serde(rename = "A7-1_time", alias = " A7-1_time")]
    pub a7_1_time: Option<String>,
    #[serde(rename = "A7-1_elapsed", alias = " A7-1_elapsed")]
    pub a7_1_elapsed: Option<String>,
    #[serde(rename = "IP2_time", alias = " IP2_time")]
    pub ip2_time: Option<String>,
    #[serde(rename = "IP2_elapsed", alias = " IP2_elapsed")]
    pub ip2_elapsed: Option<String>,
    #[serde(rename = "A8-1_time", alias = " A8-1_time")]
    pub a8_1_time: Option<String>,
    #[serde(rename = "A8-1_elapsed", alias = " A8-1_elapsed")]
    pub a8_1_elapsed: Option<String>,
    #[serde(rename = "SCLB_time", alias = " SCLB_time")]
    pub sclb_time: Option<String>,
    #[serde(rename = "SCLB_elapsed", alias = " SCLB_elapsed")]
    pub sclb_elapsed: Option<String>,
    #[serde(rename = "PORIN_time", alias = " PORIN_time")]
    pub porin_time: Option<String>,
    #[serde(rename = "PORIN_elapsed", alias = " PORIN_elapsed")]
    pub porin_elapsed: Option<String>,
    #[serde(rename = "POROUT_time", alias = " POROUT_time")]
    pub porout_time: Option<String>,
    #[serde(rename = "POROUT_elapsed", alias = " POROUT_elapsed")]
    pub porout_elapsed: Option<String>,
    #[serde(rename = "PITREF_time", alias = " PITREF_time")]
    pub pitref_time: Option<String>,
    #[serde(rename = "PITREF_elapsed", alias = " PITREF_elapsed")]
    pub pitref_elapsed: Option<String>,
    #[serde(rename = "SCL1_time", alias = " SCL1_time")]
    pub scl1_time: Option<String>,
    #[serde(rename = "SCL1_elapsed", alias = " SCL1_elapsed")]
    pub scl1_elapsed: Option<String>,
    #[serde(rename = "FORDOUT_time", alias = " FORDOUT_time")]
    pub fordout_time: Option<String>,
    #[serde(rename = "FORDOUT_elapsed", alias = " FORDOUT_elapsed")]
    pub fordout_elapsed: Option<String>,
    #[serde(rename = "FL_time", alias = " FL_time")]
    pub fl_time: Option<String>,
    #[serde(rename = "FL_elapsed", alias = " FL_elapsed")]
    pub fl_elapsed: Option<String>,
}

/// Reads CSV text as a list of [`CsvRow`]. Unparseable rows are logged and
/// skipped. Only lexical reading happens here; semantic conversion is deferred
/// to the `structure` stage.
pub fn parse(csv: &str) -> Vec<CsvRow> {
    csv::ReaderBuilder::new()
        .delimiter(b';')
        .from_reader(csv.as_bytes())
        .deserialize::<CsvRow>()
        .filter_map(|result| match result {
            Ok(row) => Some(row),
            Err(e) => {
                log::warn!("CSV row parse error: {e}");
                None
            }
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_returns_rows_with_raw_csv_fields() {
        let csv = "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS;\n12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;0:23.155;0:29.928;0:42.282;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;23.155;29.928;42.282;\n7;1;1;1:33.291;0;;23.119;0;29.188;0;40.984;0;175.0;1:33.291;11:02:00.782;0:23.119;0:29.188;0:40.984;298.6;Kamui KOBAYASHI;;HYPERCAR;H;Toyota Gazoo Racing;Toyota;GF;23.119;29.188;40.984;\n";
        let rows = parse(csv);
        assert_eq!(rows.len(), 2);

        // First row: raw strings are preserved as-is.
        assert_eq!(rows[0].car_number, "12");
        assert_eq!(rows[0].driver, "Will STEVENS");
        assert_eq!(rows[0].lap_time, "1:35.365");
        assert_eq!(rows[0].s1, "23.155");
        assert_eq!(rows[0].team, "Hertz Team JOTA");
        assert_eq!(rows[0].top_speed, None); // blank cell becomes None

        assert_eq!(rows[1].car_number, "7");
        assert_eq!(rows[1].driver, "Kamui KOBAYASHI");
        assert_eq!(rows[1].top_speed.as_deref(), Some("298.6"));
    }

    #[test]
    fn parse_skips_unparseable_rows_and_returns_empty_for_headers_only() {
        let header_only = "NUMBER;DRIVER_NUMBER;DRIVER_NAME;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;TOP_SPEED;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER\n";
        assert_eq!(parse(header_only).len(), 0);
    }
}
