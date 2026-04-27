/// CSV 行を `xxx_laps.json` 出力用の `RawLap` に整形するモジュール。
/// 出力 JSON 形状は Rust 版 CLI の
/// `motorsport::cli::stages::output::RawLap` (`#[serde(rename_all =
/// "camelCase")]`) と一致する 22 フィールドの camelCase キー:
///   carNumber, driverNumber, lapNumber, lapTime, lapImprovement,
///   crossingFinishLineInPit, s1, s1Improvement, s2, s2Improvement,
///   s3, s3Improvement, kph, elapsed, hour, topSpeed, driverName,
///   pitTime, class, group, team, manufacturer
///
/// `lapTime` / `s1` / `s2` / `s3` / `elapsed` / `pitTime` は `Duration`
/// で正規形 (`"0:01:41.031"` -> `"1:41.031"` 等) に整形される。一方
/// `hour` は CSV 上の時刻表記 (`"HH:MM:SS.sss"`) — duration ではないので
/// 正規化を通さず文字列そのままを保持する。
mod RawLap {

    use Json.JsonValue.{JsonObject, JsonString, JsonInt, JsonFloat, JsonArray}

    pub type alias RawLap = {
        carNumber = String,
        driverNumber = Int32,
        lapNumber = Int32,
        lapTime = String,
        lapImprovement = Int32,
        crossingFinishLineInPit = String,
        s1 = String,
        s1Improvement = Int32,
        s2 = String,
        s2Improvement = Int32,
        s3 = String,
        s3Improvement = Int32,
        kph = String,
        elapsed = String,
        hour = String,
        topSpeed = String,
        driverName = String,
        pitTime = String,
        class = String,
        group = String,
        team = String,
        manufacturer = String
    }

    pub def fromCsvRow(row: Csv.CsvRow): Option[RawLap] =
        forM(
            carNumber               <- List.nth(0, row);
            driverNumberStr         <- List.nth(1, row);
            lapNumberStr            <- List.nth(2, row);
            lapTime                 <- List.nth(3, row);
            lapImprovementStr       <- List.nth(4, row);
            crossingFinishLineInPit <- List.nth(5, row);
            s1                      <- List.nth(6, row);
            s1ImprovementStr        <- List.nth(7, row);
            s2                      <- List.nth(8, row);
            s2ImprovementStr        <- List.nth(9, row);
            s3                      <- List.nth(10, row);
            s3ImprovementStr        <- List.nth(11, row);
            kph                     <- List.nth(12, row);
            elapsed                 <- List.nth(13, row);
            hour                    <- List.nth(14, row);
            topSpeed                <- List.nth(18, row);
            driverName              <- List.nth(19, row);
            pitTime                 <- List.nth(20, row);
            class                   <- List.nth(21, row);
            group                   <- List.nth(22, row);
            team                    <- List.nth(23, row);
            manufacturer            <- List.nth(24, row)
        ) yield {
            carNumber               = carNumber,
            driverNumber            = parseIntOrZero(driverNumberStr),
            lapNumber               = parseIntOrZero(lapNumberStr),
            lapTime                 = Duration.normalize(lapTime),
            lapImprovement          = parseIntOrZero(lapImprovementStr),
            crossingFinishLineInPit = crossingFinishLineInPit,
            s1                      = Duration.normalize(s1),
            s1Improvement           = parseIntOrZero(s1ImprovementStr),
            s2                      = Duration.normalize(s2),
            s2Improvement           = parseIntOrZero(s2ImprovementStr),
            s3                      = Duration.normalize(s3),
            s3Improvement           = parseIntOrZero(s3ImprovementStr),
            kph                     = kph,
            elapsed                 = Duration.normalize(elapsed),
            hour                    = hour,
            topSpeed                = stripTrailingDotZero(topSpeed),
            driverName              = driverName,
            pitTime                 = Duration.normalize(pitTime),
            class                   = class,
            group                   = group,
            team                    = team,
            manufacturer            = manufacturer
        }

    pub def fromCsvRows(rows: List[Csv.CsvRow]): List[RawLap] =
        rows |> List.filterMap(fromCsvRow)

    pub def toJson(rawLap: RawLap): Json.JsonValue =
        JsonObject(
            ("carNumber",               JsonString(rawLap#carNumber)) ::
            ("driverNumber",            JsonInt(rawLap#driverNumber)) ::
            ("lapNumber",               JsonInt(rawLap#lapNumber)) ::
            ("lapTime",                 JsonString(rawLap#lapTime)) ::
            ("lapImprovement",          JsonInt(rawLap#lapImprovement)) ::
            ("crossingFinishLineInPit", JsonString(rawLap#crossingFinishLineInPit)) ::
            ("s1",                      JsonString(rawLap#s1)) ::
            ("s1Improvement",           JsonInt(rawLap#s1Improvement)) ::
            ("s2",                      JsonString(rawLap#s2)) ::
            ("s2Improvement",           JsonInt(rawLap#s2Improvement)) ::
            ("s3",                      JsonString(rawLap#s3)) ::
            ("s3Improvement",           JsonInt(rawLap#s3Improvement)) ::
            ("kph",                     kphValue(rawLap#kph)) ::
            ("elapsed",                 JsonString(rawLap#elapsed)) ::
            ("hour",                    JsonString(rawLap#hour)) ::
            ("topSpeed",                JsonString(rawLap#topSpeed)) ::
            ("driverName",              JsonString(rawLap#driverName)) ::
            ("pitTime",                 JsonString(rawLap#pitTime)) ::
            ("class",                   JsonString(rawLap#class)) ::
            ("group",                   JsonString(rawLap#group)) ::
            ("team",                    JsonString(rawLap#team)) ::
            ("manufacturer",            JsonString(rawLap#manufacturer)) ::
            Nil
        )

    pub def toJsonArray(rawLaps: List[RawLap]): Json.JsonValue =
        JsonArray(List.map(toJson, rawLaps))

    /// 文字列が `.0` で終わっていればその2文字を落とす。それ以外はそのまま。
    /// 例: `"86.0"` -> `"86"`、`"116.3"` -> `"116.3"`、`""` -> `""`。
    def stripTrailingDotZero(s: String): String =
        if (String.endsWith({suffix = ".0"}, s))
            String.dropRight(2, s)
        else
            s

    /// CSV の KPH 文字列を JSON 数値に変換する。
    /// 末尾が `.0` の値や整数表記は `JsonInt` に、それ以外で Float としてパースできれば `JsonFloat` に、
    /// パース不能の場合は文字列のまま `JsonString` で返す (フェイルセーフ)。
    def kphValue(s: String): Json.JsonValue =
        let trimmed = stripTrailingDotZero(s);
        match Int32.parse(10, trimmed) {
            case Ok(n)  => JsonInt(n)
            case Err(_) =>
                match Float64.fromString(trimmed) {
                    case Some(f) => JsonFloat(f)
                    case None    => JsonString(s)
                }
        }

    /// 10進整数としてパースし、失敗時は 0 を返す。`driverNumber` や
    /// `lapImprovement` のような「空セル/不正値はゼロ扱い」の CSV 列で使う。
    def parseIntOrZero(s: String): Int32 =
        match Int32.parse(10, s) {
            case Ok(n)  => n
            case Err(_) => 0
        }

}
