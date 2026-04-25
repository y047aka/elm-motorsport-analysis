//! パイプラインを流れる中間表現のドメイン型。
//!
//! CSV と JSON 出力のあいだで使われる語彙を、役割ごとに分割して表現する:
//!
//! - `LapRecord`: 1ラップを完全に記述する（`Lap` ＋ 補助情報）
//! - `CarInfo`: 車両単位で共有されるメタデータ
//! - `LapStats`: CSV からのみ取れる追加メトリクス
//! - `SectorTimesRaw`: CSV の S1/S2/S3 生文字列（空欄検知のため保持）
//! - `MiniSectorTimes` / `MiniSectorEntry`: Le Mans 24h 固有の15区間ミニセクター
//! - `BestTimes` / `MiniSectorBests`: ラップ走行中に累積更新されるベストタイム

use motorsport::duration::{self, Duration};
use motorsport::lap::Lap;

/// パイプラインを流れる1ラップのドメインオブジェクト。
#[derive(Debug, Clone)]
pub struct LapRecord {
    pub lap: Lap,
    pub car: CarInfo,
    pub stats: LapStats,
    pub sectors: SectorTimesRaw,
    pub mini_sectors: Option<MiniSectorTimes>,
}

/// 車両単位で共有されるメタデータ（各ラップに複製されて入ってくる）。
#[derive(Debug, Clone)]
pub struct CarInfo {
    pub class: String,
    pub group: String,
    pub team: String,
    pub manufacturer: String,
}

/// CSV からのみ取れる補助メトリクス。
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

/// CSV の S1/S2/S3 列の生文字列。空欄検知のために保持する。
#[derive(Debug, Clone)]
pub struct SectorTimesRaw {
    pub s1: String,
    pub s2: String,
    pub s3: String,
}

/// ミニセクター1区間の生データ。
#[derive(Debug, Clone, Default)]
pub struct MiniSectorEntry {
    pub time: Option<String>,
    pub elapsed: Option<String>,
}

impl MiniSectorEntry {
    /// `time` を Duration としてパースする（None / パース失敗は 0）。
    pub fn parse_time(&self) -> Duration {
        parse_opt(&self.time)
    }

    /// `elapsed` を Duration としてパースする（None / パース失敗は 0）。
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

/// Le Mans 24h のミニセクター全15区間。
#[derive(Debug, Clone, Default)]
pub struct MiniSectorTimes {
    pub scl2: MiniSectorEntry,
    pub z4: MiniSectorEntry,
    pub ip1: MiniSectorEntry,
    pub z12: MiniSectorEntry,
    pub sclc: MiniSectorEntry,
    pub a7_1: MiniSectorEntry,
    pub ip2: MiniSectorEntry,
    pub a8_1: MiniSectorEntry,
    pub sclb: MiniSectorEntry,
    pub porin: MiniSectorEntry,
    pub porout: MiniSectorEntry,
    pub pitref: MiniSectorEntry,
    pub scl1: MiniSectorEntry,
    pub fordout: MiniSectorEntry,
    pub fl: MiniSectorEntry,
}

impl MiniSectorTimes {
    /// 全エントリが空なら `None` を返す（ミニセクターを持たないイベント向け）。
    pub fn into_optional(self) -> Option<Self> {
        if self.has_any() { Some(self) } else { None }
    }

    fn has_any(&self) -> bool {
        self.entries().iter().any(|e| e.has_content())
    }

    fn entries(&self) -> [&MiniSectorEntry; 15] {
        [
            &self.scl2,
            &self.z4,
            &self.ip1,
            &self.z12,
            &self.sclc,
            &self.a7_1,
            &self.ip2,
            &self.a8_1,
            &self.sclb,
            &self.porin,
            &self.porout,
            &self.pitref,
            &self.scl1,
            &self.fordout,
            &self.fl,
        ]
    }
}

/// ラップ走行中に累積更新されるベストタイム。
#[derive(Debug, Clone, Default)]
pub struct BestTimes {
    pub lap: Option<Duration>,
    pub s1: Option<Duration>,
    pub s2: Option<Duration>,
    pub s3: Option<Duration>,
    pub mini: MiniSectorBests,
}

impl BestTimes {
    /// 現在ラップ値でラップ・S1/S2/S3 ベストを更新する（0 は無視）。
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

    /// 現在ラップのミニセクター値でベストを更新する。
    pub fn update_mini(&mut self, mini: &MiniSectorTimes) {
        self.mini.update_from(mini);
    }
}

/// 15区間すべてのミニセクターベストタイム。
#[derive(Debug, Clone, Default)]
pub struct MiniSectorBests {
    pub scl2: Option<Duration>,
    pub z4: Option<Duration>,
    pub ip1: Option<Duration>,
    pub z12: Option<Duration>,
    pub sclc: Option<Duration>,
    pub a7_1: Option<Duration>,
    pub ip2: Option<Duration>,
    pub a8_1: Option<Duration>,
    pub sclb: Option<Duration>,
    pub porin: Option<Duration>,
    pub porout: Option<Duration>,
    pub pitref: Option<Duration>,
    pub scl1: Option<Duration>,
    pub fordout: Option<Duration>,
    pub fl: Option<Duration>,
}

impl MiniSectorBests {
    fn update_from(&mut self, mini: &MiniSectorTimes) {
        self.scl2 = best(self.scl2, mini.scl2.parse_time());
        self.z4 = best(self.z4, mini.z4.parse_time());
        self.ip1 = best(self.ip1, mini.ip1.parse_time());
        self.z12 = best(self.z12, mini.z12.parse_time());
        self.sclc = best(self.sclc, mini.sclc.parse_time());
        self.a7_1 = best(self.a7_1, mini.a7_1.parse_time());
        self.ip2 = best(self.ip2, mini.ip2.parse_time());
        self.a8_1 = best(self.a8_1, mini.a8_1.parse_time());
        self.sclb = best(self.sclb, mini.sclb.parse_time());
        self.porin = best(self.porin, mini.porin.parse_time());
        self.porout = best(self.porout, mini.porout.parse_time());
        self.pitref = best(self.pitref, mini.pitref.parse_time());
        self.scl1 = best(self.scl1, mini.scl1.parse_time());
        self.fordout = best(self.fordout, mini.fordout.parse_time());
        self.fl = best(self.fl, mini.fl.parse_time());
    }
}

fn best(current_best: Option<Duration>, candidate: Duration) -> Option<Duration> {
    if candidate == 0 {
        current_best
    } else {
        Some(current_best.map_or(candidate, |b| b.min(candidate)))
    }
}
