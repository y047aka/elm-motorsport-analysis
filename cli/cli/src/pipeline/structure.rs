//! ステージ2: [`CsvRow`] の列をドメイン表現の [`LapRecord`] の列に構造化する。
//!
//! CSV の平坦な文字列表現に対して、以下のような **意味論的な変換** を行う:
//! - `LAP_TIME` / `S1` / ... を [`Duration`](motorsport::duration::Duration) へ
//! - 車両メタデータ（class, group, team, manufacturer）を [`CarInfo`] へ束ねる
//! - 30個のフラットなミニセクター列を構造化された [`MiniSectorTimes`] へ
//!   （全て空のイベントは `None` に縮約）
//!
//! 字句的な読み取りはこのモジュールでは行わない（[`csv_input`](super::csv_input) の責務）。

use motorsport::duration;
use motorsport::lap::Lap;

use super::csv_input::CsvRow;
use crate::domain::{
    CarInfo, LapRecord, LapStats, MiniSectorEntry, MiniSectorTimes, SectorTimesRaw,
};

/// [`CsvRow`] のリストをドメインの [`LapRecord`] のリストに構造化する。
pub fn structure(rows: Vec<CsvRow>) -> Vec<LapRecord> {
    rows.into_iter().map(lap_record_from).collect()
}

/// CSV 1行をドメインの [`LapRecord`] に変換する純粋関数。
fn lap_record_from(row: CsvRow) -> LapRecord {
    let time = duration::from_string(&row.lap_time).unwrap_or(0);
    let s1_dur = duration::from_string(&row.s1).unwrap_or(0);
    let s2_dur = duration::from_string(&row.s2).unwrap_or(0);
    let s3_dur = duration::from_string(&row.s3).unwrap_or(0);
    let elapsed_dur = duration::from_string(&row.elapsed).unwrap_or(0);
    let pit_time_dur = row.pit_time.as_ref().and_then(|s| duration::from_string(s));

    let lap = Lap::new(
        row.car_number,
        row.driver,
        row.lap,
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
            time: row.scl2_time,
            elapsed: row.scl2_elapsed,
        },
        z4: MiniSectorEntry {
            time: row.z4_time,
            elapsed: row.z4_elapsed,
        },
        ip1: MiniSectorEntry {
            time: row.ip1_time,
            elapsed: row.ip1_elapsed,
        },
        z12: MiniSectorEntry {
            time: row.z12_time,
            elapsed: row.z12_elapsed,
        },
        sclc: MiniSectorEntry {
            time: row.sclc_time,
            elapsed: row.sclc_elapsed,
        },
        a7_1: MiniSectorEntry {
            time: row.a7_1_time,
            elapsed: row.a7_1_elapsed,
        },
        ip2: MiniSectorEntry {
            time: row.ip2_time,
            elapsed: row.ip2_elapsed,
        },
        a8_1: MiniSectorEntry {
            time: row.a8_1_time,
            elapsed: row.a8_1_elapsed,
        },
        sclb: MiniSectorEntry {
            time: row.sclb_time,
            elapsed: row.sclb_elapsed,
        },
        porin: MiniSectorEntry {
            time: row.porin_time,
            elapsed: row.porin_elapsed,
        },
        porout: MiniSectorEntry {
            time: row.porout_time,
            elapsed: row.porout_elapsed,
        },
        pitref: MiniSectorEntry {
            time: row.pitref_time,
            elapsed: row.pitref_elapsed,
        },
        scl1: MiniSectorEntry {
            time: row.scl1_time,
            elapsed: row.scl1_elapsed,
        },
        fordout: MiniSectorEntry {
            time: row.fordout_time,
            elapsed: row.fordout_elapsed,
        },
        fl: MiniSectorEntry {
            time: row.fl_time,
            elapsed: row.fl_elapsed,
        },
    }
    .into_optional();

    LapRecord {
        lap,
        car: CarInfo {
            class: row.class,
            group: row.group,
            team: row.team,
            manufacturer: row.manufacturer,
        },
        stats: LapStats {
            driver_number: row.driver_number,
            lap_improvement: row.lap_improvement,
            crossing_finish_line_in_pit: row.crossing_finish_line_in_pit,
            s1_improvement: row.s1_improvement,
            s2_improvement: row.s2_improvement,
            s3_improvement: row.s3_improvement,
            kph: row.kph,
            hour: row.hour,
            top_speed: row.top_speed,
            pit_time: pit_time_dur,
        },
        sectors: SectorTimesRaw {
            s1: row.s1,
            s2: row.s2,
            s3: row.s3,
        },
        mini_sectors,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pipeline::csv_input;

    #[test]
    fn structure_maps_car_metadata_and_lap_basics() {
        let csv = "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS;\n12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;0:23.155;0:29.928;0:42.282;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;23.155;29.928;42.282;\n";
        let rows = csv_input::parse(csv);
        let records = structure(rows);

        assert_eq!(records.len(), 1);
        let r = &records[0];
        assert_eq!(r.lap.car_number, "12");
        assert_eq!(r.lap.driver, "Will STEVENS");
        assert_eq!(r.lap.time, 95365); // 1:35.365 → 95365 ms
        assert_eq!(r.car.team, "Hertz Team JOTA");
        assert_eq!(r.car.class, "HYPERCAR");
        // S1/S2/S3 の生文字列は保持される（空欄検知用）
        assert_eq!(r.sectors.s1, "23.155");
        // ミニセクター列が空のイベントは None に縮約される
        assert!(r.mini_sectors.is_none());
    }

    #[test]
    fn structure_preserves_mini_sector_raw_strings_when_present() {
        let csv = "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS;SCL2_time;SCL2_elapsed;\n12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;0:23.155;0:29.928;0:42.282;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;23.155;29.928;42.282;8.112;0:08.112;\n";
        let rows = csv_input::parse(csv);
        let records = structure(rows);

        let mini = records[0].mini_sectors.as_ref().expect("should be Some");
        assert_eq!(mini.scl2.time.as_deref(), Some("8.112"));
        assert_eq!(mini.scl2.elapsed.as_deref(), Some("0:08.112"));
    }
}
