/// `H:MM:SS.sss` / `MM:SS.sss` / `SS.sss` 形式の時間文字列を ms 単位の
/// `Int32` と相互変換する。Rust 版 `motorsport::duration` と同じ規則:
/// 1時間以上は `H:MM:SS.sss`、1分以上は `M:SS.sss`、それ未満は `S.sss`。
///
/// 公開 API は `normalize` のみ (入力を一度パースして正規形に整形し直す)。
/// `parse` / `format` は `normalize` 内部の実装詳細として private に保つ。
mod Duration {

    /// `H:MM:SS.sss` / `MM:SS.sss` / `SS.sss` 形式の文字列を ms 単位の Int32 にパースする。
    /// 不正フォーマットは `None` を返す。
    def parse(s: String): Option[Int32] =
        match String.split({regex = "\\."}, s) {
            case wholePart :: msPart :: Nil =>
                forM(
                    seconds <- parseHmsToSeconds(wholePart);
                    millis  <- Int32.fromString(padFractionalToMs(msPart))
                ) yield seconds * 1000 + millis
            case wholeOnly :: Nil =>
                Option.map(secs -> secs * 1000, parseHmsToSeconds(wholeOnly))
            case _ => None
        }

    /// ms 単位の Int32 を `H:MM:SS.sss` / `M:SS.sss` / `S.sss` 形式に整形する。
    /// 桁ぞろえ規則は Rust 版 `motorsport::duration::to_string` と同じ。
    def format(ms: Int32): String =
        let totalSec = ms / 1000;
        let msPart   = ms - totalSec * 1000;
        let h        = totalSec / 3600;
        let m        = (totalSec - h * 3600) / 60;
        let s        = totalSec - h * 3600 - m * 60;
        if (h > 0)
            "${h}:${zeroPad2(m)}:${zeroPad2(s)}.${zeroPad3(msPart)}"
        else if (m > 0)
            "${m}:${zeroPad2(s)}.${zeroPad3(msPart)}"
        else
            "${s}.${zeroPad3(msPart)}"

    /// 入力文字列を Duration として読み直し、正規形式で再フォーマットする。
    /// 空文字列はそのまま、パース不能はそのまま返す (フェイルセーフ)。
    pub def normalize(s: String): String =
        if (String.isEmpty(s)) s
        else
            match parse(s) {
                case Some(ms) => format(ms)
                case None     => s
            }

    def parseHmsToSeconds(s: String): Option[Int32] =
        match String.split({regex = ":"}, s) {
            case h :: m :: sec :: Nil =>
                forM(
                    hi <- Int32.fromString(h);
                    mi <- Int32.fromString(m);
                    si <- Int32.fromString(sec)
                ) yield hi * 3600 + mi * 60 + si
            case m :: sec :: Nil =>
                forM(
                    mi <- Int32.fromString(m);
                    si <- Int32.fromString(sec)
                ) yield mi * 60 + si
            case sec :: Nil =>
                Int32.fromString(sec)
            case _ => None
        }

    def padFractionalToMs(s: String): String =
        let len = String.length(s);
        if (len >= 3) String.take(3, s)
        else s + String.repeat(3 - len, "0")

    def zeroPad2(n: Int32): String =
        if (n < 10) "0${n}" else "${n}"

    def zeroPad3(n: Int32): String =
        if (n < 10) "00${n}"
        else if (n < 100) "0${n}"
        else "${n}"

}
