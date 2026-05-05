mod Util.Duration {

    pub type alias Duration = Int32

    pub def toMillis(s: String): Option[Int32] =
        if (String.isEmpty(s)) None
        else match String.split({regex = "\\."}, s) {
            case wholePart :: msPart :: Nil =>
                forM(
                    seconds <- parseHmsToSeconds(wholePart);
                    millis  <- Int32.fromString(padFractionalToMs(msPart))
                ) yield seconds * 1000 + millis
            case wholeOnly :: Nil =>
                Option.map(secs -> secs * 1000, parseHmsToSeconds(wholeOnly))
            case _ => None
        }

    pub def format(ms: Int32): String =
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
