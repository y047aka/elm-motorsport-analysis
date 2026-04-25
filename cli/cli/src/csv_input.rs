//! ステージ1: CSV を読み取り、ラップ単位の中間表現に変換する。
//!
//! 型定義（`LapWithMetadata` / `Metadata` / `ExtraData` / `MiniSectorsRaw` / `MiniSectorRaw`）は
//! 現状のものをそのまま移設している。型の整理は後続のステップで行う。

use motorsport::{Lap, duration};
use serde::Deserialize;

/// CSV解析用の中間構造体
#[derive(Debug, Deserialize)]
pub struct CsvRow {
    #[serde(rename = "NUMBER", alias = " NUMBER")]
    car_number: String,
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
    pub pit_time: Option<String>, // Raw string from CSV, will be converted to Duration
    #[serde(rename = "CLASS", alias = " CLASS")]
    pub class: String,
    #[serde(rename = "GROUP", alias = " GROUP")]
    pub group: String,
    #[serde(rename = "TEAM", alias = " TEAM")]
    pub team: String,
    #[serde(rename = "MANUFACTURER", alias = " MANUFACTURER")]
    pub manufacturer: String,
    // Le Mans 24h 専用：ミニセクター列（存在しないイベントもあるためOption）
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

/// JSON出力用のミニセクター構造体
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MiniSectorRaw {
    pub time: String,
    pub elapsed: String,
}

/// JSON出力用のミニセクター集合
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MiniSectorsRaw {
    pub scl2: MiniSectorRaw,
    pub z4: MiniSectorRaw,
    pub ip1: MiniSectorRaw,
    pub z12: MiniSectorRaw,
    pub sclc: MiniSectorRaw,
    pub a7_1: MiniSectorRaw,
    pub ip2: MiniSectorRaw,
    pub a8_1: MiniSectorRaw,
    pub sclb: MiniSectorRaw,
    pub porin: MiniSectorRaw,
    pub porout: MiniSectorRaw,
    pub pitref: MiniSectorRaw,
    pub scl1: MiniSectorRaw,
    pub fordout: MiniSectorRaw,
    pub fl: MiniSectorRaw,
}

/// Lapとメタデータを組み合わせた構造体
#[derive(Debug, Clone)]
pub struct LapWithMetadata {
    pub lap: Lap,
    pub metadata: Metadata,
    pub csv_data: ExtraData,
}

/// 車両のメタデータ情報
#[derive(Debug, Clone)]
pub struct Metadata {
    pub class: String,
    pub group: String,
    pub team: String,
    pub manufacturer: String,
}

/// CSVから取得した追加データ
#[derive(Debug, Clone)]
pub struct ExtraData {
    pub driver_number: u32,
    pub lap_improvement: i32,
    pub crossing_finish_line_in_pit: String,
    pub s1_improvement: i32,
    pub s2_improvement: i32,
    pub s3_improvement: i32,
    pub kph: f32,
    pub hour: String,
    pub top_speed: Option<String>,
    pub pit_time: Option<duration::Duration>,
    // 元のCSVセクター文字列値（空欄検出のため）
    pub s1_raw: String,
    pub s2_raw: String,
    pub s3_raw: String,
    pub mini_sectors: Option<MiniSectorsRaw>,
    // ミニセクターの生データ（ベストタイム計算のため）
    pub scl2_time: Option<String>,
    pub scl2_elapsed: Option<String>,
    pub z4_time: Option<String>,
    pub z4_elapsed: Option<String>,
    pub ip1_time: Option<String>,
    pub ip1_elapsed: Option<String>,
    pub z12_time: Option<String>,
    pub z12_elapsed: Option<String>,
    pub sclc_time: Option<String>,
    pub sclc_elapsed: Option<String>,
    pub a7_1_time: Option<String>,
    pub a7_1_elapsed: Option<String>,
    pub ip2_time: Option<String>,
    pub ip2_elapsed: Option<String>,
    pub a8_1_time: Option<String>,
    pub a8_1_elapsed: Option<String>,
    pub sclb_time: Option<String>,
    pub sclb_elapsed: Option<String>,
    pub porin_time: Option<String>,
    pub porin_elapsed: Option<String>,
    pub porout_time: Option<String>,
    pub porout_elapsed: Option<String>,
    pub pitref_time: Option<String>,
    pub pitref_elapsed: Option<String>,
    pub scl1_time: Option<String>,
    pub scl1_elapsed: Option<String>,
    pub fordout_time: Option<String>,
    pub fordout_elapsed: Option<String>,
    pub fl_time: Option<String>,
    pub fl_elapsed: Option<String>,
}

/// CSVからLapのリストを生成する
pub fn parse_laps_from_csv(csv: &str) -> Vec<LapWithMetadata> {
    csv::ReaderBuilder::new()
        .delimiter(b';')
        .from_reader(csv.as_bytes())
        .deserialize::<CsvRow>()
        .filter_map(|result| match result {
            Ok(row) => Some(lap_with_metadata_from(row)),
            Err(e) => {
                eprintln!("Lap parse error: {e}");
                None
            }
        })
        .collect()
}

/// CSVの行データをLapWithMetadataに変換する純粋関数
fn lap_with_metadata_from(row: CsvRow) -> LapWithMetadata {
    let time = duration::from_string(&row.lap_time).unwrap_or(0);
    let s1 = duration::from_string(&row.s1).unwrap_or(0);
    let s2 = duration::from_string(&row.s2).unwrap_or(0);
    let s3 = duration::from_string(&row.s3).unwrap_or(0);
    let elapsed = duration::from_string(&row.elapsed).unwrap_or(0);

    // ミニセクターは所有権を移す前に参照から構築しておく
    let mini_sectors_data = build_mini_sectors(&row);

    let lap = Lap::new(
        row.car_number,
        row.driver,
        row.lap,
        None,
        time,
        time,
        s1,
        s2,
        s3,
        s1,
        s2,
        s3,
        elapsed,
    );

    let metadata = Metadata {
        class: row.class,
        group: row.group,
        team: row.team,
        manufacturer: row.manufacturer,
    };

    let csv_data = ExtraData {
        driver_number: row.driver_number,
        lap_improvement: row.lap_improvement,
        crossing_finish_line_in_pit: row.crossing_finish_line_in_pit,
        s1_improvement: row.s1_improvement,
        s2_improvement: row.s2_improvement,
        s3_improvement: row.s3_improvement,
        kph: row.kph,
        hour: row.hour,
        top_speed: row.top_speed,
        pit_time: row.pit_time.as_ref().and_then(|s| duration::from_string(s)),
        // 元のCSV値を保存
        s1_raw: row.s1,
        s2_raw: row.s2,
        s3_raw: row.s3,
        mini_sectors: mini_sectors_data,
        // ミニセクターの生データ
        scl2_time: row.scl2_time,
        scl2_elapsed: row.scl2_elapsed,
        z4_time: row.z4_time,
        z4_elapsed: row.z4_elapsed,
        ip1_time: row.ip1_time,
        ip1_elapsed: row.ip1_elapsed,
        z12_time: row.z12_time,
        z12_elapsed: row.z12_elapsed,
        sclc_time: row.sclc_time,
        sclc_elapsed: row.sclc_elapsed,
        a7_1_time: row.a7_1_time,
        a7_1_elapsed: row.a7_1_elapsed,
        ip2_time: row.ip2_time,
        ip2_elapsed: row.ip2_elapsed,
        a8_1_time: row.a8_1_time,
        a8_1_elapsed: row.a8_1_elapsed,
        sclb_time: row.sclb_time,
        sclb_elapsed: row.sclb_elapsed,
        porin_time: row.porin_time,
        porin_elapsed: row.porin_elapsed,
        porout_time: row.porout_time,
        porout_elapsed: row.porout_elapsed,
        pitref_time: row.pitref_time,
        pitref_elapsed: row.pitref_elapsed,
        scl1_time: row.scl1_time,
        scl1_elapsed: row.scl1_elapsed,
        fordout_time: row.fordout_time,
        fordout_elapsed: row.fordout_elapsed,
        fl_time: row.fl_time,
        fl_elapsed: row.fl_elapsed,
    };

    LapWithMetadata {
        lap,
        metadata,
        csv_data,
    }
}

pub(crate) fn normalize_cell(opt: &Option<String>) -> Option<String> {
    opt.as_ref().and_then(|s| {
        let trimmed = s.trim();
        if trimmed.is_empty() {
            None
        } else {
            Some(trimmed.to_string())
        }
    })
}

fn build_mini_sectors(row: &CsvRow) -> Option<MiniSectorsRaw> {
    // いずれかの値が存在すればミニセクターありとみなす
    let any_present = [
        &row.scl2_time,
        &row.scl2_elapsed,
        &row.z4_time,
        &row.z4_elapsed,
        &row.ip1_time,
        &row.ip1_elapsed,
        &row.z12_time,
        &row.z12_elapsed,
        &row.sclc_time,
        &row.sclc_elapsed,
        &row.a7_1_time,
        &row.a7_1_elapsed,
        &row.ip2_time,
        &row.ip2_elapsed,
        &row.a8_1_time,
        &row.a8_1_elapsed,
        &row.sclb_time,
        &row.sclb_elapsed,
        &row.porin_time,
        &row.porin_elapsed,
        &row.porout_time,
        &row.porout_elapsed,
        &row.pitref_time,
        &row.pitref_elapsed,
        &row.scl1_time,
        &row.scl1_elapsed,
        &row.fordout_time,
        &row.fordout_elapsed,
        &row.fl_time,
        &row.fl_elapsed,
    ]
    .iter()
    .any(|v| normalize_cell(v).is_some());

    if !any_present {
        return None;
    }

    let mk = |time: &Option<String>, elapsed: &Option<String>| MiniSectorRaw {
        time: normalize_cell(time).unwrap_or_default(),
        elapsed: normalize_cell(elapsed).unwrap_or_default(),
    };

    Some(MiniSectorsRaw {
        scl2: mk(&row.scl2_time, &row.scl2_elapsed),
        z4: mk(&row.z4_time, &row.z4_elapsed),
        ip1: mk(&row.ip1_time, &row.ip1_elapsed),
        z12: mk(&row.z12_time, &row.z12_elapsed),
        sclc: mk(&row.sclc_time, &row.sclc_elapsed),
        a7_1: mk(&row.a7_1_time, &row.a7_1_elapsed),
        ip2: mk(&row.ip2_time, &row.ip2_elapsed),
        a8_1: mk(&row.a8_1_time, &row.a8_1_elapsed),
        sclb: mk(&row.sclb_time, &row.sclb_elapsed),
        porin: mk(&row.porin_time, &row.porin_elapsed),
        porout: mk(&row.porout_time, &row.porout_elapsed),
        pitref: mk(&row.pitref_time, &row.pitref_elapsed),
        scl1: mk(&row.scl1_time, &row.scl1_elapsed),
        fordout: mk(&row.fordout_time, &row.fordout_elapsed),
        fl: mk(&row.fl_time, &row.fl_elapsed),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_laps_from_csv() {
        let csv = "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS;\n12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;0:23.155;0:29.928;0:42.282;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;23.155;29.928;42.282;\n7;1;1;1:33.291;0;;23.119;0;29.188;0;40.984;0;175.0;1:33.291;11:02:00.782;0:23.119;0:29.188;0:40.984;298.6;Kamui KOBAYASHI;;HYPERCAR;H;Toyota Gazoo Racing;Toyota;GF;23.119;29.188;40.984;\n";
        let laps_with_metadata = parse_laps_from_csv(csv);
        assert_eq!(laps_with_metadata.len(), 2);
        assert_eq!(laps_with_metadata[0].lap.car_number, "12");
        assert_eq!(laps_with_metadata[0].lap.driver, "Will STEVENS");
        assert_eq!(laps_with_metadata[0].lap.lap, 1);
        assert_eq!(laps_with_metadata[0].metadata.team, "Hertz Team JOTA");
        assert_eq!(laps_with_metadata[0].metadata.manufacturer, "Porsche");
        assert_eq!(laps_with_metadata[1].lap.car_number, "7");
        assert_eq!(laps_with_metadata[1].lap.driver, "Kamui KOBAYASHI");
        assert_eq!(laps_with_metadata[1].lap.lap, 1);
        assert_eq!(laps_with_metadata[1].metadata.team, "Toyota Gazoo Racing");
        assert_eq!(laps_with_metadata[1].metadata.manufacturer, "Toyota");
    }
}
