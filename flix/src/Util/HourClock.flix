/// Wall-clock time-of-day in milliseconds since midnight.
///
/// 不変条件: 0 <= ms < DAY_MS。`Util.Duration.toMillis` は `H:MM:SS` / `M:SS` /
/// `SS` を区別なく受け入れるが、Hour は時刻として「コロンが 2 個」かつ
/// `< 24h` の値のみを受理する。
///
/// `offsetFrom(elapsedMs)` は `(hourMs - elapsedMs) mod 24h` を計算するため、
/// エンデュランスレースで日跨ぎ(hour が 24h で wrap、elapsed は単調増加)
/// しても呼び出し側は wrap を意識せずに「レーススタート時刻のオフセット」を
/// 比較できる。
mod Util.HourClock {

    use Util.Duration

    pub def dayMs(): Int32 = 86400000

    pub enum Hour {
        case Hour(Int32)
    }

    /// `H:MM:SS.mmm` 形式 (コロン 2 個) のみ受理する。
    /// 空欄、`MM:SS`、`SS`、24h 以上、その他パース不能なら Err(raw)。
    /// Err は元の文字列をそのまま保持し、診断時に出力できるようにする。
    pub def parse(raw: String): Result[String, Hour] =
        let trimmed = String.trim(raw);
        let parts = String.split({regex = ":"}, trimmed);
        if (List.length(parts) != 3) Err(raw)
        else
            match Duration.toMillis(trimmed) {
                case Some(ms) =>
                    if (ms >= 0 and ms < dayMs()) Ok(Hour.Hour(ms))
                    else Err(raw)
                case None => Err(raw)
            }

    pub def msSinceMidnight(h: Hour): Int32 =
        match h {
            case Hour.Hour(ms) => ms
        }

    /// `(self - elapsedMs) mod 24h`。結果は `[0, 24h)` の範囲に正規化される。
    /// Flix の整数除算は 0 方向への切り捨て(truncated toward zero)なので、
    /// 負の余りが出た場合は dayMs を加えて非負化する。
    pub def offsetFrom(h: Hour, elapsedMs: Int32): Int32 =
        match h {
            case Hour.Hour(ms) =>
                let d = dayMs();
                let diff = ms - elapsedMs;
                let q = diff / d;
                let r = diff - q * d;
                if (r < 0) r + d else r
        }

}
