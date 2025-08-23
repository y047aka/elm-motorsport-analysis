use motorsport::{Car, Class, Driver, Lap, MetaData, MiniSector, MiniSectors, duration};
use serde::Deserialize;
use std::collections::HashMap;

/// ミニセクターのベストタイム追跡用構造体
#[derive(Debug, Clone)]
struct MiniSectorBests {
    pub best_scl2: Option<u32>,
    pub best_z4: Option<u32>,
    pub best_ip1: Option<u32>,
    pub best_z12: Option<u32>,
    pub best_sclc: Option<u32>,
    pub best_a7_1: Option<u32>,
    pub best_ip2: Option<u32>,
    pub best_a8_1: Option<u32>,
    pub best_sclb: Option<u32>,
    pub best_porin: Option<u32>,
    pub best_porout: Option<u32>,
    pub best_pitref: Option<u32>,
    pub best_scl1: Option<u32>,
    pub best_fordout: Option<u32>,
    pub best_fl: Option<u32>,
}

impl MiniSectorBests {
    fn new() -> Self {
        MiniSectorBests {
            best_scl2: None,
            best_z4: None,
            best_ip1: None,
            best_z12: None,
            best_sclc: None,
            best_a7_1: None,
            best_ip2: None,
            best_a8_1: None,
            best_sclb: None,
            best_porin: None,
            best_porout: None,
            best_pitref: None,
            best_scl1: None,
            best_fordout: None,
            best_fl: None,
        }
    }

    /// ベストタイムを更新（0でない場合のみ）
    fn update_best(best: Option<u32>, current: u32) -> Option<u32> {
        if current > 0 {
            Some(best.map_or(current, |b| b.min(current)))
        } else {
            best
        }
    }

    /// 指定されたミニセクターのベストタイムを更新
    fn update_from_raw(&mut self, extra_data: &ExtraData) {
        let parse_duration =
            |opt_str: &Option<String>| opt_str.as_ref().and_then(|s| duration::from_string(s));

        if let Some(time) = parse_duration(&extra_data.scl2_time) {
            self.best_scl2 = Self::update_best(self.best_scl2, time);
        }
        if let Some(time) = parse_duration(&extra_data.z4_time) {
            self.best_z4 = Self::update_best(self.best_z4, time);
        }
        if let Some(time) = parse_duration(&extra_data.ip1_time) {
            self.best_ip1 = Self::update_best(self.best_ip1, time);
        }
        if let Some(time) = parse_duration(&extra_data.z12_time) {
            self.best_z12 = Self::update_best(self.best_z12, time);
        }
        if let Some(time) = parse_duration(&extra_data.sclc_time) {
            self.best_sclc = Self::update_best(self.best_sclc, time);
        }
        if let Some(time) = parse_duration(&extra_data.a7_1_time) {
            self.best_a7_1 = Self::update_best(self.best_a7_1, time);
        }
        if let Some(time) = parse_duration(&extra_data.ip2_time) {
            self.best_ip2 = Self::update_best(self.best_ip2, time);
        }
        if let Some(time) = parse_duration(&extra_data.a8_1_time) {
            self.best_a8_1 = Self::update_best(self.best_a8_1, time);
        }
        if let Some(time) = parse_duration(&extra_data.sclb_time) {
            self.best_sclb = Self::update_best(self.best_sclb, time);
        }
        if let Some(time) = parse_duration(&extra_data.porin_time) {
            self.best_porin = Self::update_best(self.best_porin, time);
        }
        if let Some(time) = parse_duration(&extra_data.porout_time) {
            self.best_porout = Self::update_best(self.best_porout, time);
        }
        if let Some(time) = parse_duration(&extra_data.pitref_time) {
            self.best_pitref = Self::update_best(self.best_pitref, time);
        }
        if let Some(time) = parse_duration(&extra_data.scl1_time) {
            self.best_scl1 = Self::update_best(self.best_scl1, time);
        }
        if let Some(time) = parse_duration(&extra_data.fordout_time) {
            self.best_fordout = Self::update_best(self.best_fordout, time);
        }
        if let Some(time) = parse_duration(&extra_data.fl_time) {
            self.best_fl = Self::update_best(self.best_fl, time);
        }
    }
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

fn normalize_cell(opt: &Option<String>) -> Option<String> {
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

/// ExtraDataからMiniSectors構造体を作成（ベストタイム付き）
fn build_mini_sectors_with_bests(
    extra_data: &ExtraData,
    bests: &MiniSectorBests,
) -> Option<MiniSectors> {
    // いずれかの値が存在すればミニセクターありとみなす
    let any_present = [
        &extra_data.scl2_time,
        &extra_data.scl2_elapsed,
        &extra_data.z4_time,
        &extra_data.z4_elapsed,
        &extra_data.ip1_time,
        &extra_data.ip1_elapsed,
        &extra_data.z12_time,
        &extra_data.z12_elapsed,
        &extra_data.sclc_time,
        &extra_data.sclc_elapsed,
        &extra_data.a7_1_time,
        &extra_data.a7_1_elapsed,
        &extra_data.ip2_time,
        &extra_data.ip2_elapsed,
        &extra_data.a8_1_time,
        &extra_data.a8_1_elapsed,
        &extra_data.sclb_time,
        &extra_data.sclb_elapsed,
        &extra_data.porin_time,
        &extra_data.porin_elapsed,
        &extra_data.porout_time,
        &extra_data.porout_elapsed,
        &extra_data.pitref_time,
        &extra_data.pitref_elapsed,
        &extra_data.scl1_time,
        &extra_data.scl1_elapsed,
        &extra_data.fordout_time,
        &extra_data.fordout_elapsed,
        &extra_data.fl_time,
        &extra_data.fl_elapsed,
    ]
    .iter()
    .any(|v| normalize_cell(v).is_some());

    if !any_present {
        return None;
    }

    let parse_duration = |opt_str: &Option<String>| {
        opt_str
            .as_ref()
            .and_then(|s| duration::from_string(s))
            .unwrap_or(0)
    };

    let parse_elapsed = |opt_str: &Option<String>| {
        opt_str
            .as_ref()
            .and_then(|s| duration::from_string(s))
            .unwrap_or(0)
    };

    let mk_minisector = |time_opt: &Option<String>,
                         elapsed_opt: &Option<String>,
                         best_opt: Option<u32>| MiniSector {
        time: parse_duration(time_opt),
        elapsed: parse_elapsed(elapsed_opt),
        best: best_opt.unwrap_or(0),
    };

    Some(MiniSectors {
        scl2: mk_minisector(
            &extra_data.scl2_time,
            &extra_data.scl2_elapsed,
            bests.best_scl2,
        ),
        z4: mk_minisector(&extra_data.z4_time, &extra_data.z4_elapsed, bests.best_z4),
        ip1: mk_minisector(
            &extra_data.ip1_time,
            &extra_data.ip1_elapsed,
            bests.best_ip1,
        ),
        z12: mk_minisector(
            &extra_data.z12_time,
            &extra_data.z12_elapsed,
            bests.best_z12,
        ),
        sclc: mk_minisector(
            &extra_data.sclc_time,
            &extra_data.sclc_elapsed,
            bests.best_sclc,
        ),
        a7_1: mk_minisector(
            &extra_data.a7_1_time,
            &extra_data.a7_1_elapsed,
            bests.best_a7_1,
        ),
        ip2: mk_minisector(
            &extra_data.ip2_time,
            &extra_data.ip2_elapsed,
            bests.best_ip2,
        ),
        a8_1: mk_minisector(
            &extra_data.a8_1_time,
            &extra_data.a8_1_elapsed,
            bests.best_a8_1,
        ),
        sclb: mk_minisector(
            &extra_data.sclb_time,
            &extra_data.sclb_elapsed,
            bests.best_sclb,
        ),
        porin: mk_minisector(
            &extra_data.porin_time,
            &extra_data.porin_elapsed,
            bests.best_porin,
        ),
        porout: mk_minisector(
            &extra_data.porout_time,
            &extra_data.porout_elapsed,
            bests.best_porout,
        ),
        pitref: mk_minisector(
            &extra_data.pitref_time,
            &extra_data.pitref_elapsed,
            bests.best_pitref,
        ),
        scl1: mk_minisector(
            &extra_data.scl1_time,
            &extra_data.scl1_elapsed,
            bests.best_scl1,
        ),
        fordout: mk_minisector(
            &extra_data.fordout_time,
            &extra_data.fordout_elapsed,
            bests.best_fordout,
        ),
        fl: mk_minisector(&extra_data.fl_time, &extra_data.fl_elapsed, bests.best_fl),
    })
}

/// Lapとメタデータを組み合わせた構造体
#[derive(Debug, Clone)]
pub struct LapWithMetadata {
    pub lap: Lap,
    pub metadata: Metadata,
    pub csv_data: ExtraData,
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

/// 車両のメタデータ情報
#[derive(Debug, Clone)]
pub struct Metadata {
    pub class: String,
    pub group: String,
    pub team: String,
    pub manufacturer: String,
}

/// LapWithMetadataリストをCarごとにグループ化する
pub fn group_laps_by_car(laps_with_metadata: Vec<LapWithMetadata>) -> Vec<Car> {
    // インデックス付きグループ化でCSV出現順序を保持
    let mut car_data: HashMap<String, (Vec<LapWithMetadata>, Vec<String>, usize)> = HashMap::new();

    for (index, lap_with_meta) in laps_with_metadata.into_iter().enumerate() {
        let car_number = lap_with_meta.lap.car_number.clone();
        let driver_name = lap_with_meta.lap.driver.clone();

        // 車両データを蓄積
        car_data
            .entry(car_number)
            .and_modify(|(laps, drivers, _)| {
                laps.push(lap_with_meta.clone());
                if !drivers.contains(&driver_name) {
                    drivers.push(driver_name.clone());
                }
            })
            .or_insert((
                vec![lap_with_meta],
                vec![driver_name],
                index, // 最初の出現インデックスを保存
            ));
    }

    // 車両を作成し、最初の出現順序でソート
    let mut cars_with_index: Vec<(usize, Car)> = car_data
        .into_iter()
        .map(
            |(car_number, (laps_with_metadata, driver_names, first_index))| {
                let car = car_from_grouped_data(car_number, laps_with_metadata, driver_names);
                (first_index, car)
            },
        )
        .collect();

    // CSVの出現順序でソート
    cars_with_index.sort_by_key(|(index, _)| *index);

    let mut cars: Vec<Car> = cars_with_index.into_iter().map(|(_, car)| car).collect();

    // 位置計算を実行
    calculate_positions(&mut cars);

    cars
}

/// グループ化されたデータからCarを作成し、ベストタイムを計算する関数
fn car_from_grouped_data(
    car_number: String,
    laps_with_metadata: Vec<LapWithMetadata>,
    driver_names: Vec<String>,
) -> Car {
    let drivers = drivers_from(driver_names);
    let car_metadata = &laps_with_metadata[0].metadata;
    let class = class_from(&car_metadata.class);
    let meta = metadata_from(car_number, drivers, class, car_metadata);

    let processed_laps = process_laps(laps_with_metadata);
    car_with_lap_data(meta, processed_laps)
}

/// ドライバー名のリストからDriverのリストを作成
fn drivers_from(driver_names: Vec<String>) -> Vec<Driver> {
    driver_names
        .into_iter()
        .enumerate()
        .map(|(i, name)| Driver::new(name, i == 0))
        .collect()
}

/// クラス文字列をClass enumにマッピング
fn class_from(class_str: &str) -> Class {
    match class_str {
        "HYPERCAR" => Class::HYPERCAR,
        "LMP2" => Class::LMP2,
        "LMGT3" => Class::LMGT3,
        _ => Class::HYPERCAR, // デフォルト
    }
}

/// MetaDataを作成
fn metadata_from(
    car_number: String,
    drivers: Vec<Driver>,
    class: Class,
    car_metadata: &Metadata,
) -> MetaData {
    MetaData::new(
        car_number,
        drivers,
        class,
        car_metadata.group.clone(),
        car_metadata.team.clone(),
        car_metadata.manufacturer.clone(),
    )
}

/// ラップデータを含むCarを作成
fn car_with_lap_data(meta: MetaData, processed_laps: Vec<Lap>) -> Car {
    use motorsport::car::Status;

    let mut car = Car::new(meta, 1, processed_laps);
    car.status = Status::Racing;
    car
}

/// ベストタイムを追跡してラップを処理する関数（Elm実装に基づく）
fn process_laps(mut laps_with_metadata: Vec<LapWithMetadata>) -> Vec<Lap> {
    // ラップ番号順にソート
    laps_with_metadata.sort_by_key(|lap| lap.lap.lap);

    let mut best_lap_time: Option<u32> = None;
    let mut best_s1: Option<u32> = None;
    let mut best_s2: Option<u32> = None;
    let mut best_s3: Option<u32> = None;
    let mut mini_sector_bests = MiniSectorBests::new();
    let mut processed_laps = Vec::new();

    for lap_with_meta in laps_with_metadata {
        let lap = &lap_with_meta.lap;
        let csv_row = &lap_with_meta.csv_data;

        // 現在のラップタイムとセクタータイムを取得
        let current_lap_time = lap.time;
        let current_s1 = lap.sector_1;
        let current_s2 = lap.sector_2;
        let current_s3 = lap.sector_3;

        // ベストタイムを更新（0でない場合のみ）
        let update_best = |best: Option<u32>, current: u32| -> Option<u32> {
            if current > 0 {
                Some(best.map_or(current, |b| b.min(current)))
            } else {
                best
            }
        };

        best_lap_time = update_best(best_lap_time, current_lap_time);
        best_s1 = update_best(best_s1, current_s1);
        best_s2 = update_best(best_s2, current_s2);
        best_s3 = update_best(best_s3, current_s3);

        // ミニセクターのベストタイムを更新
        mini_sector_bests.update_from_raw(csv_row);

        // ミニセクター情報を作成（ベストタイム付き）
        let mini_sectors = build_mini_sectors_with_bests(csv_row, &mini_sector_bests);

        // 新しいLapを作成（ベストタイムとミニセクター情報を設定）
        let processed_lap = Lap::new_with_mini_sectors(
            lap.car_number.clone(),
            lap.driver.clone(),
            lap.lap,
            lap.position,
            lap.time,
            best_lap_time.unwrap_or(0), // best field
            lap.sector_1,
            lap.sector_2,
            lap.sector_3,
            best_s1.unwrap_or(0), // s1_best field
            best_s2.unwrap_or(0), // s2_best field
            best_s3.unwrap_or(0), // s3_best field
            lap.elapsed,
            mini_sectors,
        );

        processed_laps.push(processed_lap);
    }

    processed_laps
}

/// 各車両の各ラップでの位置を計算する
fn calculate_positions(cars: &mut [Car]) {
    if cars.is_empty() {
        return;
    }

    // スタートポジションを計算（1週目の経過時間順）
    start_positions(cars);

    // 最大ラップ数を取得
    let max_lap = cars
        .iter()
        .flat_map(|car| &car.laps)
        .map(|lap| lap.lap)
        .max()
        .unwrap_or(0);

    // 各ラップの位置を計算
    for lap_num in 1..=max_lap {
        position_for_lap(cars, lap_num);
    }
}

/// スタートポジションを計算（1週目の経過時間順）
fn start_positions(cars: &mut [Car]) {
    // 1週目のラップを収集してソート
    let mut lap1_times: Vec<(String, u32)> = cars
        .iter()
        .filter_map(|car| {
            car.laps
                .iter()
                .find(|lap| lap.lap == 1)
                .map(|lap| (car.meta_data.car_number.clone(), lap.elapsed))
        })
        .collect();
    lap1_times.sort_by_key(|(_, elapsed)| *elapsed);

    // スタートポジションを設定
    for car in cars.iter_mut() {
        if let Some(position) = lap1_times
            .iter()
            .position(|(car_num, _)| car_num == &car.meta_data.car_number)
        {
            // Elm互換のため0-basedのindexをそのまま使用
            // 注意: 将来的には1-basedの position + 1 に変更する可能性がある
            car.start_position = position as i32;
        }
    }
}

/// 特定のラップでの各車両の位置を計算
fn position_for_lap(cars: &mut [Car], lap_num: u32) {
    // 指定されたラップでの各車両の経過時間を収集してソート
    let mut lap_times: Vec<(String, u32, usize)> = cars
        .iter()
        .enumerate()
        .filter_map(|(car_idx, car)| {
            car.laps
                .iter()
                .find(|l| l.lap == lap_num)
                .map(|lap| (car.meta_data.car_number.clone(), lap.elapsed, car_idx))
        })
        .collect();
    lap_times.sort_by_key(|(_, elapsed, _)| *elapsed);

    // 各車両のラップに位置を設定
    for (position, (car_number, _, car_idx)) in lap_times.iter().enumerate() {
        if let Some(car) = cars.get_mut(*car_idx) {
            if let Some(lap) = car
                .laps
                .iter_mut()
                .find(|l| l.lap == lap_num && l.car_number == *car_number)
            {
                // Elm互換のため0-basedのindexをそのまま使用
                // 注意: 将来的には1-basedの position + 1 に変更する可能性がある
                lap.position = Some(position as u32);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // テストヘルパー関数
    fn create_test_metadata(team: &str, manufacturer: &str) -> Metadata {
        Metadata {
            class: "HYPERCAR".to_string(),
            group: "H".to_string(),
            team: team.to_string(),
            manufacturer: manufacturer.to_string(),
        }
    }

    fn create_test_extra_data(
        driver_number: u32,
        kph: f32,
        lap_improvement: i32,
        top_speed: Option<&str>,
    ) -> ExtraData {
        ExtraData {
            driver_number,
            lap_improvement,
            crossing_finish_line_in_pit: String::new(),
            s1_improvement: 0,
            s2_improvement: 0,
            s3_improvement: 0,
            kph,
            hour: "11:02:02.856".to_string(),
            top_speed: top_speed.map(|s| s.to_string()),
            pit_time: None,
            s1_raw: "23.155".to_string(),
            s2_raw: "29.928".to_string(),
            s3_raw: "42.282".to_string(),
            mini_sectors: None,
            // ミニセクターの生データ（テスト用）
            scl2_time: None,
            scl2_elapsed: None,
            z4_time: None,
            z4_elapsed: None,
            ip1_time: None,
            ip1_elapsed: None,
            z12_time: None,
            z12_elapsed: None,
            sclc_time: None,
            sclc_elapsed: None,
            a7_1_time: None,
            a7_1_elapsed: None,
            ip2_time: None,
            ip2_elapsed: None,
            a8_1_time: None,
            a8_1_elapsed: None,
            sclb_time: None,
            sclb_elapsed: None,
            porin_time: None,
            porin_elapsed: None,
            porout_time: None,
            porout_elapsed: None,
            pitref_time: None,
            pitref_elapsed: None,
            scl1_time: None,
            scl1_elapsed: None,
            fordout_time: None,
            fordout_elapsed: None,
            fl_time: None,
            fl_elapsed: None,
        }
    }

    fn create_test_lap_with_metadata(
        car_number: &str,
        driver: &str,
        lap_num: u32,
        position: Option<u32>,
        times: (u32, u32, u32, u32, u32), // (lap_time, s1, s2, s3, elapsed)
        metadata: Metadata,
        extra_data: ExtraData,
    ) -> LapWithMetadata {
        let (lap_time, s1, s2, s3, elapsed) = times;
        LapWithMetadata {
            lap: Lap::new(
                car_number.to_string(),
                driver.to_string(),
                lap_num,
                position,
                lap_time,
                lap_time,
                s1,
                s2,
                s3,
                s1,
                s2,
                s3,
                elapsed,
            ),
            metadata,
            csv_data: extra_data,
        }
    }

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

    #[test]
    fn test_group_laps_by_car() {
        let laps_with_metadata = vec![
            create_test_lap_with_metadata(
                "12",
                "Will STEVENS",
                1,
                Some(3),
                (95365, 23155, 29928, 42282, 95365),
                create_test_metadata("Hertz Team JOTA", "Porsche"),
                create_test_extra_data(1, 160.7, 0, None),
            ),
            create_test_lap_with_metadata(
                "12",
                "Robin FRIJNS",
                2,
                Some(2),
                (113610, 23155, 29928, 42282, 113610),
                create_test_metadata("Hertz Team JOTA", "Porsche"),
                create_test_extra_data(2, 165.2, 1, Some("298.6")),
            ),
            create_test_lap_with_metadata(
                "7",
                "Kamui KOBAYASHI",
                1,
                Some(1),
                (93291, 23119, 29188, 40984, 93291),
                create_test_metadata("Toyota Gazoo Racing", "Toyota"),
                create_test_extra_data(1, 175.0, 0, Some("298.6")),
            ),
        ];
        let cars = group_laps_by_car(laps_with_metadata);
        assert_eq!(cars.len(), 2);

        let car12 = cars
            .iter()
            .find(|c| c.meta_data.car_number == "12")
            .unwrap();
        assert_eq!(car12.laps.len(), 2);
        assert_eq!(car12.meta_data.team, "Hertz Team JOTA");
        assert_eq!(car12.meta_data.manufacturer, "Porsche");
        assert_eq!(car12.meta_data.drivers.len(), 2); // 2人のドライバー

        let car7 = cars.iter().find(|c| c.meta_data.car_number == "7").unwrap();
        assert_eq!(car7.laps.len(), 1);
        assert_eq!(car7.meta_data.team, "Toyota Gazoo Racing");
        assert_eq!(car7.meta_data.manufacturer, "Toyota");
        assert_eq!(car7.meta_data.drivers.len(), 1); // 1人のドライバー
    }

    #[test]
    fn test_best_time_tracking() {
        // Test best time tracking logic based on Elm implementation
        let team_metadata = create_test_metadata("Hertz Team JOTA", "Porsche");

        let laps_with_metadata = vec![
            // Lap 1: Sets initial best times
            create_test_lap_with_metadata(
                "12",
                "Will STEVENS",
                1,
                None,
                (95365, 23155, 29928, 42282, 95365),
                team_metadata.clone(),
                create_test_extra_data(1, 160.7, 0, None),
            ),
            // Lap 2: Faster in all areas - updates all bests
            create_test_lap_with_metadata(
                "12",
                "Will STEVENS",
                2,
                None,
                (92245, 22500, 29100, 40645, 187610),
                team_metadata.clone(),
                create_test_extra_data(1, 165.2, 1, None),
            ),
            // Lap 3: Slower overall but tests mixed sector performance
            create_test_lap_with_metadata(
                "12",
                "Will STEVENS",
                3,
                None,
                (94000, 23000, 29500, 41500, 281610),
                team_metadata,
                create_test_extra_data(1, 163.0, 0, None),
            ),
        ];

        let cars = group_laps_by_car(laps_with_metadata);
        assert_eq!(cars.len(), 1);

        let car = &cars[0];
        assert_eq!(car.laps.len(), 3);

        // Verify best time tracking across laps
        let expected_bests = [
            (95365, 23155, 29928, 42282), // Lap 1: initial bests
            (92245, 22500, 29100, 40645), // Lap 2: all improved
            (92245, 22500, 29100, 40645), // Lap 3: bests remain from lap 2
        ];

        for (i, (expected_lap_best, expected_s1, expected_s2, expected_s3)) in
            expected_bests.iter().enumerate()
        {
            let lap = &car.laps[i];
            assert_eq!(
                lap.best,
                *expected_lap_best,
                "Lap {} best time mismatch",
                i + 1
            );
            assert_eq!(lap.s1_best, *expected_s1, "Lap {} S1 best mismatch", i + 1);
            assert_eq!(lap.s2_best, *expected_s2, "Lap {} S2 best mismatch", i + 1);
            assert_eq!(lap.s3_best, *expected_s3, "Lap {} S3 best mismatch", i + 1);
        }
    }
}
