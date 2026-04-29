mod Cli.Validation {

    use Util.Duration
    use RawLap.RawLap

    /// データ整合性チェックで検出される違反種別。
    /// 各バリアントは違反発生ラップと、ルール固有の期待値・実測値を保持する。
    pub enum Violation {
        /// `s1 + s2 + s3 == lapTime` を満たさない。
        /// 引数: 該当ラップ / lapTime(ms) / 合算値(ms) / 空欄だったセクタ名のリスト
        case SectorSum(RawLap, Int32, Int32, List[String])

        /// `elapsed[n] == elapsed[n-1] + lapTime[n]` を満たさない。
        /// 引数: 該当ラップ / 期待値(ms) / 実測値(ms)
        case ElapsedCumulative(RawLap, Int32, Int32)

        /// 同一カー内の `hourMs - elapsedMs` が一定でない(24h 単位の wrap は許容)。
        /// 引数: 該当ラップ / 基準オフセット(ms) / 実測オフセット(ms)
        case HourElapsedOffset(RawLap, Int32, Int32)
    }

    /// イベント名と違反のリストから、stderr 用の文字列メッセージを生成する。
    pub def validate(eventName: String, laps: List[RawLap]): List[String] =
        detect(laps) |> List.map(v -> formatViolation(eventName, v))

    /// すべてのルールを実行し、検出された Violation のリストを返す純粋関数。
    pub def detect(laps: List[RawLap]): List[Violation] =
        let perLap = laps |> List.filterMap(lap -> resultToOption(checkSectorSum(lap)));
        let grouped = groupByCar(laps);
        let perCar = grouped |> List.flatMap(pair -> match pair {
            case (_, carLaps) =>
                let sorted = List.sortBy(l -> l#lapNumber, carLaps);
                List.append(
                    checkElapsedCumulative(sorted),
                    checkHourElapsedConsistency(sorted)
                )
        });
        List.append(perLap, perCar)

    def resultToOption(r: Result[Violation, Unit]): Option[Violation] =
        match r {
            case Ok(_)  => None
            case Err(v) => Some(v)
        }

    def groupByCar(laps: List[RawLap]): List[(String, List[RawLap])] =
        // Per-car validation sorts by lapNumber, so the order within each group does not matter.
        laps
            |> List.foldLeft(
                (acc, lap) -> Map.insertWith(
                    (existing, fresh) -> List.append(fresh, existing),
                    lap#carNumber,
                    lap :: Nil,
                    acc
                ),
                Map.empty()
            )
            |> Map.toList

    def checkSectorSum(lap: RawLap): Result[Violation, Unit] =
        match Duration.toMillis(lap#lapTime) {
            case None        => Ok(())
            case Some(lapMs) =>
                let (s1Ms, s1Blank) = sectorMs(lap#s1, "s1");
                let (s2Ms, s2Blank) = sectorMs(lap#s2, "s2");
                let (s3Ms, s3Blank) = sectorMs(lap#s3, "s3");
                let sum = s1Ms + s2Ms + s3Ms;
                if (sum == lapMs) Ok(())
                else
                    let blanks = (s1Blank :: s2Blank :: s3Blank :: Nil) |> List.filterMap(x -> x);
                    Err(Violation.SectorSum(lap, lapMs, sum, blanks))
        }

    def sectorMs(value: String, name: String): (Int32, Option[String]) =
        match Duration.toMillis(value) {
            case Some(ms) => (ms, None)
            case None     => (0, Some(name))
        }

    def checkElapsedCumulative(sortedLaps: List[RawLap]): List[Violation] =
        match sortedLaps {
            case Nil      => Nil
            case _ :: Nil => Nil
            case _ :: rest =>
                let pairs = List.zip(sortedLaps, rest);
                pairs |> List.filterMap(pair -> match pair {
                    case (prev, curr) => resultToOption(checkAdjacentElapsed(prev, curr))
                })
        }

    def checkAdjacentElapsed(prev: RawLap, curr: RawLap): Result[Violation, Unit] =
        match (Duration.toMillis(prev#elapsed),
               Duration.toMillis(curr#elapsed),
               Duration.toMillis(curr#lapTime)) {
            case (Some(prevElapsed), Some(currElapsed), Some(currLapMs)) =>
                let expected = prevElapsed + currLapMs;
                if (expected == currElapsed) Ok(())
                else Err(Violation.ElapsedCumulative(curr, expected, currElapsed))
            case _ => Ok(())
        }

    def checkHourElapsedConsistency(sortedLaps: List[RawLap]): List[Violation] =
        let offsets = sortedLaps |> List.filterMap(l ->
            match (Duration.toMillis(l#hour), Duration.toMillis(l#elapsed)) {
                case (Some(hourMs), Some(elapsedMs)) => Some((l, hourMs - elapsedMs))
                case _                               => None
            }
        );
        match offsets {
            case Nil               => Nil
            case (_, base) :: rest =>
                rest |> List.filterMap(pair -> match pair {
                    case (lap, offset) => resultToOption(checkHourOffset(lap, base, offset))
                })
        }

    def checkHourOffset(lap: RawLap, base: Int32, offset: Int32): Result[Violation, Unit] =
        if (sameWallClockDay(offset, base)) Ok(())
        else Err(Violation.HourElapsedOffset(lap, base, offset))

    def sameWallClockDay(offset: Int32, base: Int32): Bool =
        // Endurance races may cross midnight, so hour wraps by 24h while elapsed keeps growing.
        let dayMs = 86400000;
        let diff = offset - base;
        let q = diff / dayMs;
        diff - q * dayMs == 0

    pub def formatViolation(eventName: String, v: Violation): String =
        match v {
            case Violation.SectorSum(lap, lapMs, sum, blanks) =>
                let suffix =
                    if (List.isEmpty(blanks)) ""
                    else " (blank: ${List.join(",", blanks)})";
                formatLine(eventName, lap, "sector sum", formatMs(lapMs), formatMs(sum)) + suffix
            case Violation.ElapsedCumulative(lap, expected, actual) =>
                formatLine(eventName, lap, "elapsed cumulative", formatMs(expected), formatMs(actual))
            case Violation.HourElapsedOffset(lap, base, offset) =>
                formatLine(eventName, lap, "hour-elapsed offset", formatMs(base), formatMs(offset))
        }

    def formatLine(eventName: String, lap: RawLap, rule: String, expected: String, actual: String): String =
        "${eventName}: [car ${lap#carNumber} #${lap#lapNumber}] ${rule}: expected ${expected}, got ${actual}"

    def formatMs(ms: Int32): String =
        if (ms < 0) "-" + Duration.format(0 - ms)
        else Duration.format(ms)

}
