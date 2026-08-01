pub type Duration = u32;

/// Duration文字列をミリ秒に変換
/// 例: "1:35.365" -> 95365, "23.155" -> 23155
pub fn from_string(s: &str) -> Option<Duration> {
    let parts: Vec<&str> = s.split(':').collect();

    // 桁として読む。`parse::<f64>()` はミリ秒を二進小数で正確に表せないので、
    // 丸めて戻す必要があった。小数第3位までしか来ないため、小数部はそのまま
    // ミリ秒。短ければ右をゼロ埋めし、長ければそこまでしか読まない。
    let convert_seconds = |s: &str| -> Option<u32> {
        match s.split('.').collect::<Vec<&str>>().as_slice() {
            [whole, fraction] => {
                let mut ms: String = fraction.chars().take(3).collect();
                while ms.len() < 3 {
                    ms.push('0');
                }
                Some(whole.parse::<u32>().ok()? * 1000 + ms.parse::<u32>().ok()?)
            }
            [whole] => Some(whole.parse::<u32>().ok()? * 1000),
            _ => None,
        }
    };

    match parts.as_slice() {
        [h, m, s] => {
            let hours = h.parse::<u32>().ok()?;
            let minutes = m.parse::<u32>().ok()?;
            let seconds = convert_seconds(s)?;
            Some(hours * 3600000 + minutes * 60000 + seconds)
        }
        [m, s] => {
            let minutes = m.parse::<u32>().ok()?;
            let seconds = convert_seconds(s)?;
            Some(minutes * 60000 + seconds)
        }
        [s] => convert_seconds(s),
        _ => None,
    }
}

/// ミリ秒をDuration文字列に変換
pub fn to_string(ms: Duration) -> String {
    let milliseconds = ms % 1000;

    match ms / 1000 {
        s if s < 60 => format!("{s}.{milliseconds:03}"),
        s if s < 3600 => {
            let minutes = s / 60;
            let seconds = s % 60;
            format!("{minutes}:{seconds:02}.{milliseconds:03}")
        }
        s => {
            let hours = s / 3600;
            let minutes = (s % 3600) / 60;
            let seconds = s % 60;
            format!("{hours}:{minutes:02}:{seconds:02}.{milliseconds:03}")
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{from_string, to_string};

    #[test]
    fn test_duration_from_string() {
        assert_eq!(from_string("1:35.365"), Some(95365));
        assert_eq!(from_string("23.155"), Some(23155));
        assert_eq!(from_string("0:29.928"), Some(29928));
        assert_eq!(from_string("7:06:54.321"), Some(25614321));
    }

    #[test]
    fn test_duration_to_string() {
        // Elm Duration.toString 互換の動作をテスト
        assert_eq!(to_string(0), "0.000");
        assert_eq!(to_string(4321), "4.321");
        assert_eq!(to_string(28076), "28.076");
        assert_eq!(to_string(95365), "1:35.365");
        assert_eq!(to_string(23155), "23.155");
        assert_eq!(to_string(29928), "29.928");
        assert_eq!(to_string(414321), "6:54.321");
        assert_eq!(to_string(25614321), "7:06:54.321");
    }

    #[test]
    fn test_boundary_cases() {
        assert_eq!(from_string("1:28.944"), Some(88944));
        assert_eq!(to_string(88944), "1:28.944");
        assert_eq!(from_string("60.000"), Some(60000));
        assert_eq!(to_string(60000), "1:00.000");
        assert_eq!(from_string("59.999"), Some(59999));
        assert_eq!(to_string(59999), "59.999");
    }

    #[test]
    fn test_error_handling() {
        assert_eq!(from_string(""), None);
        assert_eq!(from_string("invalid"), None);
        assert_eq!(from_string("1:2:3:4"), None);
        assert_eq!(from_string("abc:def"), None);
        // `Duration` は `u32` なので符号は表現できない。以前は `as u32` の
        // 飽和変換で無言のうちに 0 になっていた。呼び出し側
        // (`stages::structure`) は警告を出したうえで 0 にフォールバックする。
        assert_eq!(from_string("-1.0"), None);
        assert_eq!(from_string("999:59.999"), Some(59999999));
        assert_eq!(to_string(59999999), "16:39:59.999");
    }

    #[test]
    fn test_precision() {
        assert_eq!(from_string("1.001"), Some(1001));
        assert_eq!(from_string("1.999"), Some(1999));
        assert_eq!(to_string(1001), "1.001");
        assert_eq!(to_string(1999), "1.999");
        assert_eq!(to_string(123), "0.123");
        assert_eq!(to_string(1), "0.001");
    }
}
