/// Wall-clock time-of-day in milliseconds since midnight.
///
/// Invariant: `0 <= ms < DAY_MS`. Unlike `Duration`, which accepts `H:MM:SS`,
/// `M:SS`, and `SS` interchangeably, `HourClock` only accepts strict
/// time-of-day values with exactly two colons and a result below 24 h.
///
/// `offset_from(elapsed)` computes `(self - elapsed) mod 24 h`, so an
/// endurance-race day-rollover (hour wraps at midnight while elapsed keeps
/// growing) is handled internally — callers can compare offsets directly.
pub const DAY_MS: u32 = 86_400_000;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct HourClock(u32);

impl HourClock {
    /// Accepts only `H:MM:SS.mmm` (exactly two colons). Empty strings,
    /// `MM:SS`-style values, values >= 24 h, and any other unparseable text
    /// return `None` so the original input can be reported by the caller.
    pub fn parse(s: &str) -> Option<Self> {
        let trimmed = s.trim();
        // Require exactly two colons (three parts).
        if trimmed.chars().filter(|&c| c == ':').count() != 2 {
            return None;
        }
        let ms = crate::duration::from_string(trimmed)?;
        if ms < DAY_MS {
            Some(Self(ms))
        } else {
            None
        }
    }

    /// Returns the raw milliseconds-since-midnight value.
    pub fn ms_since_midnight(self) -> u32 {
        self.0
    }

    /// Computes `(self − elapsed) mod 24 h`, normalised to `[0, 24 h)`.
    ///
    /// Integer subtraction may go negative when elapsed has crossed midnight,
    /// so we work in `i64` and apply a standard signed-remainder correction.
    pub fn offset_from(self, elapsed: u32) -> u32 {
        let day = DAY_MS as i64;
        let diff = self.0 as i64 - elapsed as i64;
        let r = diff % day;
        if r < 0 { (r + day) as u32 } else { r as u32 }
    }

    /// Renders as `HH:MM:SS.mmm` with the hour zero-padded to two digits.
    ///
    /// `duration::to_string` strips a leading-zero hour (e.g. `0:01:35.365`),
    /// which would break round-trip identity against WEC CSVs that always use
    /// two-digit hours. This method always pads to two digits.
    pub fn format(self) -> String {
        let ms = self.0;
        let total_sec = ms / 1000;
        let ms_part = ms % 1000;
        let hr = total_sec / 3600;
        let m = (total_sec % 3600) / 60;
        let s = total_sec % 60;
        format!("{hr:02}:{m:02}:{s:02}.{ms_part:03}")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_accepts_two_colon_format() {
        let h = HourClock::parse("11:02:02.856").unwrap();
        // 11*3600000 + 2*60000 + 2856 = 39_600_000 + 120_000 + 2_856 = 39_722_856
        assert_eq!(h.ms_since_midnight(), 39_722_856);
    }

    #[test]
    fn parse_rejects_single_colon_format() {
        assert!(HourClock::parse("1:35.365").is_none());
    }

    #[test]
    fn parse_rejects_empty() {
        assert!(HourClock::parse("").is_none());
    }

    #[test]
    fn parse_rejects_values_ge_24h() {
        assert!(HourClock::parse("24:00:00.000").is_none());
    }

    #[test]
    fn parse_accepts_hour_zero() {
        let h = HourClock::parse("0:00:00.000").unwrap();
        assert_eq!(h.ms_since_midnight(), 0);
    }

    #[test]
    fn format_zero_pads_hour() {
        let h = HourClock::parse("9:05:03.001").unwrap();
        assert_eq!(h.format(), "09:05:03.001");
    }

    #[test]
    fn format_round_trips() {
        let raw = "11:02:02.856";
        assert_eq!(HourClock::parse(raw).unwrap().format(), raw);
    }

    #[test]
    fn offset_from_no_wrap() {
        // hour=11:02:02.856 (39_722_856 ms), elapsed=1:02:02.856 (3_722_856 ms)
        // offset = 39_722_856 - 3_722_856 = 36_000_000 = exactly 10 h
        let h = HourClock::parse("11:02:02.856").unwrap();
        let elapsed = 3_722_856_u32;
        assert_eq!(h.offset_from(elapsed), 36_000_000);
    }

    #[test]
    fn offset_from_with_midnight_wrap() {
        // Simulate hour < elapsed: hour=01:00:00.000 (3_600_000 ms),
        // elapsed=23:00:00.000 (82_800_000 ms) — hour has wrapped past midnight.
        // Expected offset = (3_600_000 - 82_800_000) mod 86_400_000
        //                 = -79_200_000 mod 86_400_000 = 7_200_000 = 2 h
        let h = HourClock::parse("1:00:00.000").unwrap();
        let elapsed = 82_800_000_u32;
        assert_eq!(h.offset_from(elapsed), 7_200_000);
    }
}
