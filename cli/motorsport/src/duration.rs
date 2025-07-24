pub type Duration = u32;

/// Duration文字列をミリ秒に変換
/// 例: "1:35.365" -> 95365, "23.155" -> 23155
pub fn from_string(s: &str) -> Option<Duration> {
    let parts: Vec<&str> = s.split(':').collect();

    match parts.as_slice() {
        // "hh:mm:ss.ms" 形式
        [h, m, s] => {
            let hours = h.parse::<u32>().ok()?;
            let minutes = m.parse::<u32>().ok()?;
            let seconds = s.parse::<f64>().ok()?;
            Some(hours * 3600000 + minutes * 60000 + (seconds * 1000.0) as u32)
        }
        // "mm:ss.ms" 形式
        [m, s] => {
            let minutes = m.parse::<u32>().ok()?;
            let seconds = s.parse::<f64>().ok()?;
            Some(minutes * 60000 + (seconds * 1000.0) as u32)
        }
        // "ss.ms" 形式
        [s] => {
            let seconds = s.parse::<f64>().ok()?;
            Some((seconds * 1000.0) as u32)
        }
        _ => None,
    }
}

/// ミリ秒をDuration文字列に変換（整数演算ベース、Elm互換形式）
pub fn to_string(ms: Duration) -> String {
    if ms == 0 {
        return "0.000".to_string();
    }
    
    let total_seconds = ms / 1000;
    let milliseconds = ms % 1000;
    
    if total_seconds < 60 {
        // 60秒未満: "4.321"
        format!("{}.{:03}", total_seconds, milliseconds)
    } else if total_seconds < 3600 {
        // 1時間未満: "6:54.321" 
        let minutes = total_seconds / 60;
        let seconds = total_seconds % 60;
        format!("{}:{:02}.{:03}", minutes, seconds, milliseconds)
    } else {
        // 1時間以上: "7:06:54.321"
        let hours = total_seconds / 3600;
        let minutes = (total_seconds % 3600) / 60;
        let seconds = total_seconds % 60;
        format!("{}:{:02}:{:02}.{:03}", hours, minutes, seconds, milliseconds)
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
}
