/// Wall-clock time-of-day in milliseconds since midnight.
///
/// Invariant: 0 <= ms < DAY_MS. `Util.Duration.toMillis` accepts `H:MM:SS`,
/// `M:SS`, and `SS` interchangeably; Hour, in contrast, only accepts strict
/// time-of-day values with two colons and a result below 24h.
///
/// `offsetFrom(elapsedMs)` computes `(hourMs - elapsedMs) mod 24h`, so an
/// endurance-race day-rollover (hour wraps at 24h while elapsed keeps
/// growing) is handled internally — callers can compare offsets directly
/// without thinking about midnight.
mod Util.HourClock {

    use Util.Duration

    pub def dayMs(): Int32 = 86400000

    pub enum Hour with Eq {
        case Hour(Int32)
    }

    /// Accepts only `H:MM:SS.mmm` (two colons). Empty, `MM:SS`, `SS`, values
    /// >= 24h, and any other unparseable text return `Err(raw)` so the
    /// original input can be reported.
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

    /// `(self - elapsedMs) mod 24h`, normalized to `[0, 24h)`. Flix integer
    /// division truncates toward zero, so a negative remainder is shifted
    /// up by dayMs.
    pub def offsetFrom(h: Hour, elapsedMs: Int32): Int32 =
        match h {
            case Hour.Hour(ms) =>
                let d = dayMs();
                let diff = ms - elapsedMs;
                let q = diff / d;
                let r = diff - q * d;
                if (r < 0) r + d else r
        }

    /// Renders as `HH:MM:SS.mmm` with the hour zero-padded to two digits.
    /// `Util.Duration.format` strips a leading zero hour (e.g. `0:01:35.365`),
    /// which would break byte-identity against WEC CSVs that always use
    /// two-digit hours.
    pub def format(h: Hour): String =
        match h {
            case Hour.Hour(ms) =>
                let totalSec = ms / 1000;
                let msPart = ms - totalSec * 1000;
                let hr = totalSec / 3600;
                let m = (totalSec - hr * 3600) / 60;
                let s = totalSec - hr * 3600 - m * 60;
                "${pad2(hr)}:${pad2(m)}:${pad2(s)}.${pad3(msPart)}"
        }

    def pad2(n: Int32): String =
        if (n < 10) "0${n}" else "${n}"

    def pad3(n: Int32): String =
        if (n < 10) "00${n}"
        else if (n < 100) "0${n}"
        else "${n}"

}
