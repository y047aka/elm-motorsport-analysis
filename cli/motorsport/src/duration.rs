pub type Duration = u32;

/// Duration文字列をミリ秒に変換
/// 例: "1:35.365" -> 95365, "23.155" -> 23155
///
/// 各パートは数字の並びのみを受け付ける。`Duration` は `u32` なので符号は
/// そもそも表現できず、以前は負値が `as u32` の飽和変換で無言のうちに 0 に
/// なっていた。今は `None` を返し、呼び出し側（`stages::structure`）が警告を
/// 出したうえで 0 にフォールバックする。
pub fn from_string(s: &str) -> Option<Duration> {
    let parts: Vec<&str> = s.split(':').collect();

    match parts.as_slice() {
        [h, m, s] => Some(digits(h)? * 3600000 + digits(m)? * 60000 + from_seconds(s)?),
        [m, s] => Some(digits(m)? * 60000 + from_seconds(s)?),
        [s] => from_seconds(s),
        _ => None,
    }
}

/// 秒フィールド。整数部・小数部とも整数として読む。
///
/// 以前は `parse::<f64>()` してから `round()` で戻していた。ミリ秒は秒の二進
/// 小数として正確に表せないので、読み取った値は書かれた桁そのものではなく、
/// 丸めればたまたま元に戻る程度に近い値でしかなかった。
fn from_seconds(s: &str) -> Option<Duration> {
    match s.split('.').collect::<Vec<&str>>().as_slice() {
        [whole] => Some(digits(whole)? * 1000),
        [whole, fraction] => Some(digits(whole)? * 1000 + milliseconds(fraction)?),
        _ => None,
    }
}

/// 小数部をミリ秒に。4桁まで読んで3桁に四捨五入する。
///
/// `.5005` はちょうど 0.5 ミリ秒だが `f64` にすると半分をわずかに下回るため、
/// 従来の丸めは切り下げ側に落ちていた。桁をそのまま整数として読めばずれない。
/// 1秒に繰り上がる小数（`.9999` は 1000 ミリ秒）は呼び出し側が整数秒に足すので
/// そのままでよい。
fn milliseconds(fraction: &str) -> Option<Duration> {
    if !fraction.chars().all(|c| c.is_ascii_digit()) {
        return None;
    }

    let mut padded: String = fraction.chars().take(4).collect();
    while padded.len() < 4 {
        padded.push('0');
    }

    let tenths_of_a_milli: u32 = padded.parse().ok()?;
    Some((tenths_of_a_milli + 5) / 10)
}

/// 数字の並びで、それ以外を含まないもの。`parse::<u32>()` は `+` も受け付ける。
fn digits(s: &str) -> Option<u32> {
    if s.is_empty() || !s.chars().all(|c| c.is_ascii_digit()) {
        return None;
    }
    s.parse().ok()
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
        // `Duration` が `u32` である以上、負の値は表現できない。以前は
        // `as u32` の飽和変換で無言のうちに 0 になっていた。
        assert_eq!(from_string("-1.0"), None);
        assert_eq!(from_string("1e3"), None);
        assert_eq!(from_string("1:-30.000"), None);
        assert_eq!(from_string("999:59.999"), Some(59999999));
        assert_eq!(to_string(59999999), "16:39:59.999");
    }

    #[test]
    fn test_exact_half_millisecond_rounds_up() {
        // 0.5005 秒はちょうど 500.5 ミリ秒だが、`f64` での最近傍は
        // 500.49999999999994 なので `(sec * 1000.0).round()` は 500 を返していた。
        assert_eq!(from_string("0.5005"), Some(501));
        assert_eq!(from_string("0.50950"), Some(510));
    }

    #[test]
    fn test_round_trips_with_to_string() {
        // Elm 側 (`Motorsport.DurationTest`) の fuzz テストと同じ性質。
        // レース時間の全域にわたって、書いたものがそのまま読み戻せること。
        for ms in (0..100_000_000).step_by(997) {
            assert_eq!(from_string(&to_string(ms)), Some(ms), "ms = {ms}");
        }
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
