//! ステージ1: CSV を読み取り、[`LapRecord`] の列に変換する。
//!
//! CSV 1行の平坦な文字列表現 ([`CsvRow`]) をドメインの構造化された語彙
//! ([`domain`](crate::domain) モジュールの型) へ変換するのがこのステージの責務。

use motorsport::{Lap, duration};
use serde::Deserialize;

use crate::domain::{
    CarInfo, LapRecord, LapStats, MiniSectorEntry, MiniSectorTimes, SectorTimesRaw,
};

/// CSV 1行の平坦な表現。パース直後の内部型。
#[derive(Debug, Deserialize)]
struct CsvRow {
    #[serde(rename = "NUMBER", alias = " NUMBER")]
    car_number: String,
    #[serde(rename = "DRIVER_NUMBER", alias = " DRIVER_NUMBER")]
    driver_number: u32,
    #[serde(rename = "DRIVER_NAME", alias = " DRIVER_NAME")]
    driver: String,
    #[serde(rename = "LAP_NUMBER", alias = " LAP_NUMBER")]
    lap: u32,
    #[serde(rename = "LAP_TIME", alias = " LAP_TIME")]
    lap_time: String,
    #[serde(rename = "LAP_IMPROVEMENT", alias = " LAP_IMPROVEMENT")]
    lap_improvement: i32,
    #[serde(
        rename = "CROSSING_FINISH_LINE_IN_PIT",
        alias = " CROSSING_FINISH_LINE_IN_PIT"
    )]
    crossing_finish_line_in_pit: String,
    #[serde(rename = "S1", alias = " S1")]
    s1: String,
    #[serde(rename = "S1_IMPROVEMENT", alias = " S1_IMPROVEMENT")]
    s1_improvement: i32,
    #[serde(rename = "S2", alias = " S2")]
    s2: String,
    #[serde(rename = "S2_IMPROVEMENT", alias = " S2_IMPROVEMENT")]
    s2_improvement: i32,
    #[serde(rename = "S3", alias = " S3")]
    s3: String,
    #[serde(rename = "S3_IMPROVEMENT", alias = " S3_IMPROVEMENT")]
    s3_improvement: i32,
    #[serde(rename = "KPH", alias = " KPH")]
    kph: f32,
    #[serde(rename = "ELAPSED", alias = " ELAPSED")]
    elapsed: String,
    #[serde(rename = "HOUR", alias = " HOUR")]
    hour: String,
    #[serde(rename = "TOP_SPEED", alias = " TOP_SPEED")]
    top_speed: Option<String>,
    #[serde(rename = "PIT_TIME", alias = " PIT_TIME")]
    pit_time: Option<String>,
    #[serde(rename = "CLASS", alias = " CLASS")]
    class: String,
    #[serde(rename = "GROUP", alias = " GROUP")]
    group: String,
    #[serde(rename = "TEAM", alias = " TEAM")]
    team: String,
    #[serde(rename = "MANUFACTURER", alias = " MANUFACTURER")]
    manufacturer: String,
    // Le Mans 24h 専用：ミニセクター列（存在しないイベントもあるため Option）
    #[serde(rename = "SCL2_time", alias = " SCL2_time")]
    scl2_time: Option<String>,
    #[serde(rename = "SCL2_elapsed", alias = " SCL2_elapsed")]
    scl2_elapsed: Option<String>,
    #[serde(rename = "Z4_time", alias = " Z4_time")]
    z4_time: Option<String>,
    #[serde(rename = "Z4_elapsed", alias = " Z4_elapsed")]
    z4_elapsed: Option<String>,
    #[serde(rename = "IP1_time", alias = " IP1_time")]
    ip1_time: Option<String>,
    #[serde(rename = "IP1_elapsed", alias = " IP1_elapsed")]
    ip1_elapsed: Option<String>,
    #[serde(rename = "Z12_time", alias = " Z12_time")]
    z12_time: Option<String>,
    #[serde(rename = "Z12_elapsed", alias = " Z12_elapsed")]
    z12_elapsed: Option<String>,
    #[serde(rename = "SCLC_time", alias = " SCLC_time")]
    sclc_time: Option<String>,
    #[serde(rename = "SCLC_elapsed", alias = " SCLC_elapsed")]
    sclc_elapsed: Option<String>,
    #[serde(rename = "A7-1_time", alias = " A7-1_time")]
    a7_1_time: Option<String>,
    #[serde(rename = "A7-1_elapsed", alias = " A7-1_elapsed")]
    a7_1_elapsed: Option<String>,
    #[serde(rename = "IP2_time", alias = " IP2_time")]
    ip2_time: Option<String>,
    #[serde(rename = "IP2_elapsed", alias = " IP2_elapsed")]
    ip2_elapsed: Option<String>,
    #[serde(rename = "A8-1_time", alias = " A8-1_time")]
    a8_1_time: Option<String>,
    #[serde(rename = "A8-1_elapsed", alias = " A8-1_elapsed")]
    a8_1_elapsed: Option<String>,
    #[serde(rename = "SCLB_time", alias = " SCLB_time")]
    sclb_time: Option<String>,
    #[serde(rename = "SCLB_elapsed", alias = " SCLB_elapsed")]
    sclb_elapsed: Option<String>,
    #[serde(rename = "PORIN_time", alias = " PORIN_time")]
    porin_time: Option<String>,
    #[serde(rename = "PORIN_elapsed", alias = " PORIN_elapsed")]
    porin_elapsed: Option<String>,
    #[serde(rename = "POROUT_time", alias = " POROUT_time")]
    porout_time: Option<String>,
    #[serde(rename = "POROUT_elapsed", alias = " POROUT_elapsed")]
    porout_elapsed: Option<String>,
    #[serde(rename = "PITREF_time", alias = " PITREF_time")]
    pitref_time: Option<String>,
    #[serde(rename = "PITREF_elapsed", alias = " PITREF_elapsed")]
    pitref_elapsed: Option<String>,
    #[serde(rename = "SCL1_time", alias = " SCL1_time")]
    scl1_time: Option<String>,
    #[serde(rename = "SCL1_elapsed", alias = " SCL1_elapsed")]
    scl1_elapsed: Option<String>,
    #[serde(rename = "FORDOUT_time", alias = " FORDOUT_time")]
    fordout_time: Option<String>,
    #[serde(rename = "FORDOUT_elapsed", alias = " FORDOUT_elapsed")]
    fordout_elapsed: Option<String>,
    #[serde(rename = "FL_time", alias = " FL_time")]
    fl_time: Option<String>,
    #[serde(rename = "FL_elapsed", alias = " FL_elapsed")]
    fl_elapsed: Option<String>,
}

impl CsvRow {
    /// CSV 1行をドメインの [`LapRecord`] に変換する。
    fn into_lap_record(self) -> LapRecord {
        let time = duration::from_string(&self.lap_time).unwrap_or(0);
        let s1_dur = duration::from_string(&self.s1).unwrap_or(0);
        let s2_dur = duration::from_string(&self.s2).unwrap_or(0);
        let s3_dur = duration::from_string(&self.s3).unwrap_or(0);
        let elapsed_dur = duration::from_string(&self.elapsed).unwrap_or(0);
        let pit_time_dur = self
            .pit_time
            .as_ref()
            .and_then(|s| duration::from_string(s));

        let lap = Lap::new(
            self.car_number,
            self.driver,
            self.lap,
            None,
            time,
            time,
            s1_dur,
            s2_dur,
            s3_dur,
            s1_dur,
            s2_dur,
            s3_dur,
            elapsed_dur,
        );

        let mini_sectors = MiniSectorTimes {
            scl2: MiniSectorEntry {
                time: self.scl2_time,
                elapsed: self.scl2_elapsed,
            },
            z4: MiniSectorEntry {
                time: self.z4_time,
                elapsed: self.z4_elapsed,
            },
            ip1: MiniSectorEntry {
                time: self.ip1_time,
                elapsed: self.ip1_elapsed,
            },
            z12: MiniSectorEntry {
                time: self.z12_time,
                elapsed: self.z12_elapsed,
            },
            sclc: MiniSectorEntry {
                time: self.sclc_time,
                elapsed: self.sclc_elapsed,
            },
            a7_1: MiniSectorEntry {
                time: self.a7_1_time,
                elapsed: self.a7_1_elapsed,
            },
            ip2: MiniSectorEntry {
                time: self.ip2_time,
                elapsed: self.ip2_elapsed,
            },
            a8_1: MiniSectorEntry {
                time: self.a8_1_time,
                elapsed: self.a8_1_elapsed,
            },
            sclb: MiniSectorEntry {
                time: self.sclb_time,
                elapsed: self.sclb_elapsed,
            },
            porin: MiniSectorEntry {
                time: self.porin_time,
                elapsed: self.porin_elapsed,
            },
            porout: MiniSectorEntry {
                time: self.porout_time,
                elapsed: self.porout_elapsed,
            },
            pitref: MiniSectorEntry {
                time: self.pitref_time,
                elapsed: self.pitref_elapsed,
            },
            scl1: MiniSectorEntry {
                time: self.scl1_time,
                elapsed: self.scl1_elapsed,
            },
            fordout: MiniSectorEntry {
                time: self.fordout_time,
                elapsed: self.fordout_elapsed,
            },
            fl: MiniSectorEntry {
                time: self.fl_time,
                elapsed: self.fl_elapsed,
            },
        }
        .into_optional();

        LapRecord {
            lap,
            car: CarInfo {
                class: self.class,
                group: self.group,
                team: self.team,
                manufacturer: self.manufacturer,
            },
            stats: LapStats {
                driver_number: self.driver_number,
                lap_improvement: self.lap_improvement,
                crossing_finish_line_in_pit: self.crossing_finish_line_in_pit,
                s1_improvement: self.s1_improvement,
                s2_improvement: self.s2_improvement,
                s3_improvement: self.s3_improvement,
                kph: self.kph,
                hour: self.hour,
                top_speed: self.top_speed,
                pit_time: pit_time_dur,
            },
            sectors: SectorTimesRaw {
                s1: self.s1,
                s2: self.s2,
                s3: self.s3,
            },
            mini_sectors,
        }
    }
}

/// CSV からラップレコードのリストを生成する。
pub fn parse_laps_from_csv(csv: &str) -> Vec<LapRecord> {
    csv::ReaderBuilder::new()
        .delimiter(b';')
        .from_reader(csv.as_bytes())
        .deserialize::<CsvRow>()
        .filter_map(|result| match result {
            Ok(row) => Some(row.into_lap_record()),
            Err(e) => {
                log::warn!("Lap parse error: {e}");
                None
            }
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_laps_from_csv() {
        let csv = "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS;\n12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;0:23.155;0:29.928;0:42.282;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;23.155;29.928;42.282;\n7;1;1;1:33.291;0;;23.119;0;29.188;0;40.984;0;175.0;1:33.291;11:02:00.782;0:23.119;0:29.188;0:40.984;298.6;Kamui KOBAYASHI;;HYPERCAR;H;Toyota Gazoo Racing;Toyota;GF;23.119;29.188;40.984;\n";
        let records = parse_laps_from_csv(csv);
        assert_eq!(records.len(), 2);
        assert_eq!(records[0].lap.car_number, "12");
        assert_eq!(records[0].lap.driver, "Will STEVENS");
        assert_eq!(records[0].lap.lap, 1);
        assert_eq!(records[0].car.team, "Hertz Team JOTA");
        assert_eq!(records[0].car.manufacturer, "Porsche");
        assert_eq!(records[1].lap.car_number, "7");
        assert_eq!(records[1].lap.driver, "Kamui KOBAYASHI");
        assert_eq!(records[1].lap.lap, 1);
        assert_eq!(records[1].car.team, "Toyota Gazoo Racing");
        assert_eq!(records[1].car.manufacturer, "Toyota");
    }
}
