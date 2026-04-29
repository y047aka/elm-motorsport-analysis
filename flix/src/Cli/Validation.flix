mod Cli.Validation {

    use Util.Duration
    use RawLap.RawLap

    pub def validate(eventName: String, laps: List[RawLap]): List[String] =
        let perLap = laps |> List.filterMap(checkSectorSum(eventName));
        let grouped = groupByCar(laps);
        let perCar = grouped |> List.flatMap(pair -> match pair {
            case (_, carLaps) =>
                let sorted = List.sortBy(l -> l#lapNumber, carLaps);
                List.append(
                    checkElapsedCumulative(eventName, sorted),
                    checkHourElapsedConsistency(eventName, sorted)
                )
        });
        List.append(perLap, perCar)

    def groupByCar(laps: List[RawLap]): List[(String, List[RawLap])] =
        let carNumbers = laps |> List.map(l -> l#carNumber) |> List.distinct;
        carNumbers |> List.map(cn ->
            (cn, laps |> List.filter(l -> l#carNumber == cn))
        )

    def checkSectorSum(eventName: String, lap: RawLap): Option[String] =
        match Duration.toMillis(lap#lapTime) {
            case None        => None
            case Some(lapMs) =>
                let (s1Ms, s1Blank) = sectorMs(lap#s1, "s1");
                let (s2Ms, s2Blank) = sectorMs(lap#s2, "s2");
                let (s3Ms, s3Blank) = sectorMs(lap#s3, "s3");
                let sum = s1Ms + s2Ms + s3Ms;
                if (sum == lapMs) None
                else
                    let blanks = (s1Blank :: s2Blank :: s3Blank :: Nil) |> List.filterMap(x -> x);
                    let suffix =
                        if (List.isEmpty(blanks)) ""
                        else " (blank: ${List.join(",", blanks)})";
                    Some(formatViolation(eventName, lap, "sector sum", lap#lapTime, formatMs(sum)) + suffix)
        }

    def sectorMs(value: String, name: String): (Int32, Option[String]) =
        match Duration.toMillis(value) {
            case Some(ms) => (ms, None)
            case None     => (0, Some(name))
        }

    def checkElapsedCumulative(eventName: String, sortedLaps: List[RawLap]): List[String] =
        match sortedLaps {
            case Nil      => Nil
            case _ :: Nil => Nil
            case _ :: rest =>
                let pairs = List.zip(sortedLaps, rest);
                pairs |> List.filterMap(pair -> match pair {
                    case (prev, curr) => checkAdjacentElapsed(eventName, prev, curr)
                })
        }

    def checkAdjacentElapsed(eventName: String, prev: RawLap, curr: RawLap): Option[String] =
        match (Duration.toMillis(prev#elapsed),
               Duration.toMillis(curr#elapsed),
               Duration.toMillis(curr#lapTime)) {
            case (Some(prevElapsed), Some(currElapsed), Some(currLapMs)) =>
                let expected = prevElapsed + currLapMs;
                if (expected == currElapsed) None
                else Some(formatViolation(eventName, curr, "elapsed cumulative", formatMs(expected), curr#elapsed))
            case _ => None
        }

    def checkHourElapsedConsistency(eventName: String, sortedLaps: List[RawLap]): List[String] =
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
                    case (lap, offset) =>
                        if (sameWallClockDay(offset, base)) None
                        else Some(formatViolation(eventName, lap, "hour-elapsed offset", formatMs(base), formatMs(offset)))
                })
        }

    def sameWallClockDay(offset: Int32, base: Int32): Bool =
        // Endurance races may cross midnight, so hour wraps by 24h while elapsed keeps growing.
        let dayMs = 86400000;
        let diff = offset - base;
        let q = diff / dayMs;
        diff - q * dayMs == 0

    def formatViolation(eventName: String, lap: RawLap, rule: String, expected: String, actual: String): String =
        "${eventName}: [car ${lap#carNumber} #${lap#lapNumber}] ${rule}: expected ${expected}, got ${actual}"

    def formatMs(ms: Int32): String =
        if (ms < 0) "-" + Duration.format(0 - ms)
        else Duration.format(ms)

}
