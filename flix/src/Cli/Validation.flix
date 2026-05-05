/// Source-data integrity checks run during CSV → JSON conversion.
///
/// All rules use strict 0 ms equality. Violations are returned as warnings
/// only; they do not affect the exit code. Stages.processFile prints them
/// to stderr.
///
/// Rules:
///   1. SectorSum         — `s1 + s2 + s3 == lapTime` (per row)
///   2. ElapsedDrift      — per car, `elapsed[n] == sum(lapTime[1..=n])`
///                          (cumulative-sum: every row from the first drift
///                          onward is reported)
///   3. HourElapsedOffset — across the CSV, `(hour - elapsed) mod 24h` is
///                          constant
///   4. HourUnparseable   — hour cell cannot be parsed as H:MM:SS.mmm
///
/// Design notes:
///   - HourElapsedOffset's baseline is the **first valid row in the whole
///     CSV** (race-wide, not per-car). A bad lap 1 on one car does not
///     cascade across the rest of that car.
///   - 24h wrap is folded into `Util.HourClock.offsetFrom`, so the validator
///     just compares offsets with `==`.
///   - Report order follows CSV appearance (per-lap is naturally CSV order;
///     per-car uses first-seen-index to sort the car groups).
mod Cli.Validation {

    use Util.Duration
    use Util.HourClock
    use Util.HourClock.Hour
    use RawLap.RawLap
    use RawLap.Sector

    pub enum Violation {
        /// `s1 + s2 + s3 != lapTime`.
        /// Args: lap / lapTime ms / sector sum ms / labels of blank sectors.
        case SectorSum(RawLap, Int32, Int32, List[String])

        /// `elapsed[n] != sum(lapTime[1..=n])`. Cumulative-sum based, so
        /// every row from the first drift onward is reported (sticky drift).
        /// Args: lap / expected = running sum (ms) / actual = elapsed (ms).
        case ElapsedDrift(RawLap, Int32, Int32)

        /// `(hour - elapsed) mod 24h` does not match the baseline.
        /// Args: lap / baseline offset (ms) / actual offset (ms).
        case HourElapsedOffset(RawLap, Int32, Int32)

        /// hour cell could not be parsed as H:MM:SS.mmm.
        /// Args: lap / original raw string.
        case HourUnparseable(RawLap, String)
    }

    /// Runs all rules and renders each violation as a stderr-ready string.
    pub def validate(eventName: String, laps: List[RawLap]): List[String] =
        detect(laps) |> List.map(v -> formatViolation(eventName, v))

    /// Runs all rules and returns the structured violation list (pure).
    pub def detect(laps: List[RawLap]): List[Violation] =
        let perLap = laps |> List.filterMap(lap -> resultToOption(checkSectorSum(lap)));
        let perCar = perCarViolations(laps);
        let perRace = checkHourElapsedRaceWide(laps);
        List.append(perLap, List.append(perCar, perRace))

    def resultToOption(r: Result[Violation, Unit]): Option[Violation] =
        match r {
            case Ok(_)  => None
            case Err(v) => Some(v)
        }

    /// Walks per-car elapsed-drift checks in CSV order (first-seen index).
    /// Each car's laps are sorted by lapNumber before the check.
    def perCarViolations(laps: List[RawLap]): List[Violation] =
        groupByCar(laps) |> List.flatMap(pair -> match pair {
            case (_, carLaps) =>
                let sorted = List.sortBy(l -> l#lapNumber, carLaps);
                checkElapsedDrift(sorted)
        })

    /// Groups laps by carNumber while preserving CSV appearance order:
    ///   1. first pass records carNumber → first-seen index
    ///   2. second pass collects carNumber → all laps
    ///   3. flatten, sorted by first-seen index
    def groupByCar(laps: List[RawLap]): List[(String, List[RawLap])] =
        let firstSeen = laps |> List.foldLeft(
            (acc, lap) ->
                if (Map.memberOf(lap#carNumber, acc)) acc
                else Map.insert(lap#carNumber, Map.size(acc), acc),
            Map.empty()
        );
        let grouped = laps |> List.foldLeft(
            (acc, lap) -> Map.insertWith(
                (existing, fresh) -> List.append(fresh, existing),
                lap#carNumber,
                lap :: Nil,
                acc
            ),
            Map.empty()
        );
        Map.toList(grouped) |> List.sortBy(entry -> match entry {
            case (car, _) => Map.get(car, firstSeen) |> Option.getWithDefault(0)
        })

    def checkSectorSum(lap: RawLap): Result[Violation, Unit] =
        match Duration.toMillis(lap#lapTime) {
            case None        => Ok(())
            case Some(lapMs) =>
                let (s1Ms, s1Blank) = sectorMs(lap#s1#value, "s1");
                let (s2Ms, s2Blank) = sectorMs(lap#s2#value, "s2");
                let (s3Ms, s3Blank) = sectorMs(lap#s3#value, "s3");
                let sum = s1Ms + s2Ms + s3Ms;
                if (sum == lapMs) Ok(())
                else
                    let blanks = (s1Blank :: s2Blank :: s3Blank :: Nil) |> List.filterMap(x -> x);
                    Err(Violation.SectorSum(lap, lapMs, sum, blanks))
        }

    /// Unpacks a Sector into (ms, blank-label-or-None). Err is treated as
    /// 0 ms and the field name is returned so it can be attached to the
    /// violation message.
    def sectorMs(sector: Sector, name: String): (Int32, Option[String]) =
        match sector {
            case Ok(ms)  => (ms, None)
            case Err(_)  => (0, Some(name))
        }

    /// Cumulative-sum elapsed-drift check (equivalent to Rust's `scan`).
    /// Each lap updates `running = sum(lapTime[1..=n])` and is flagged if
    /// `elapsed` disagrees. Blank/unparseable lapTime and elapsed are
    /// treated as 0 ms (matches Rust's behaviour). Once a drift starts,
    /// every subsequent lap is reported — noisier than adjacent-diff, but
    /// catches compensating drift.
    def checkElapsedDrift(sortedLaps: List[RawLap]): List[Violation] =
        let folded = sortedLaps |> List.foldLeft(
            (state, lap) -> match state {
                case (running, acc) =>
                    let lapMs   = Duration.toMillis(lap#lapTime) |> Option.getWithDefault(0);
                    let newRun  = running + lapMs;
                    let elapsed = Duration.toMillis(lap#elapsed) |> Option.getWithDefault(0);
                    if (newRun == elapsed) (newRun, acc)
                    else (newRun, Violation.ElapsedDrift(lap, newRun, elapsed) :: acc)
            },
            (0, Nil)
        );
        match folded {
            case (_, acc) => List.reverse(acc)
        }

    /// Race-wide hour-elapsed baseline check. The baseline is the first row
    /// in CSV order whose hour parses successfully; rows whose hour fails to
    /// parse are reported as HourUnparseable rather than silently skipped.
    def checkHourElapsedRaceWide(laps: List[RawLap]): List[Violation] =
        let baseline = findBaseline(laps);
        match baseline {
            case None       =>
                laps |> List.filterMap(lap -> hourUnparseableOf(lap))
            case Some(base) =>
                laps |> List.filterMap(lap -> resultToOption(checkHourLine(lap, base)))
        }

    def findBaseline(laps: List[RawLap]): Option[Int32] =
        match laps {
            case Nil          => None
            case lap :: rest  =>
                match (lap#hour, Duration.toMillis(lap#elapsed)) {
                    case (Ok(h), Some(elapsedMs)) =>
                        Some(HourClock.offsetFrom(h, elapsedMs))
                    case _ => findBaseline(rest)
                }
        }

    def checkHourLine(lap: RawLap, base: Int32): Result[Violation, Unit] =
        match lap#hour {
            case Err(raw) =>
                Err(Violation.HourUnparseable(lap, raw))
            case Ok(h) =>
                match Duration.toMillis(lap#elapsed) {
                    case None => Ok(())
                    case Some(elapsedMs) =>
                        let offset = HourClock.offsetFrom(h, elapsedMs);
                        if (offset == base) Ok(())
                        else Err(Violation.HourElapsedOffset(lap, base, offset))
                }
        }

    def hourUnparseableOf(lap: RawLap): Option[Violation] =
        match lap#hour {
            case Err(raw) => Some(Violation.HourUnparseable(lap, raw))
            case Ok(_)    => None
        }

    def formatViolation(eventName: String, v: Violation): String =
        match v {
            case Violation.SectorSum(lap, lapMs, sum, blanks) =>
                let suffix =
                    if (List.isEmpty(blanks)) ""
                    else " (blank: ${List.join(",", blanks)})";
                formatExpectedActual(eventName, lap, "sector-sum", lapMs, sum) + suffix
            case Violation.ElapsedDrift(lap, expected, actual) =>
                formatExpectedActual(eventName, lap, "elapsed-drift", expected, actual)
            case Violation.HourElapsedOffset(lap, base, offset) =>
                formatExpectedActual(eventName, lap, "hour-offset", base, offset)
            case Violation.HourUnparseable(lap, raw) =>
                "${eventName}: [car ${lap#carNumber} #${lap#lapNumber}] hour-unparseable: raw=\"${raw}\""
        }

    /// Emits `{eventName}: [car X #N] kind: expected=<fmt> (<ms>ms) actual=<fmt> (<ms>ms)`.
    /// The raw ms is included alongside the formatted Duration to keep the
    /// output both human-readable and grep-friendly (matches Rust output).
    def formatExpectedActual(eventName: String, lap: RawLap, kind: String, expected: Int32, actual: Int32): String =
        "${eventName}: [car ${lap#carNumber} #${lap#lapNumber}] ${kind}: expected=${formatMs(expected)} (${expected}ms) actual=${formatMs(actual)} (${actual}ms)"

    def formatMs(ms: Int32): String =
        if (ms < 0) "-" + Duration.format(0 - ms)
        else Duration.format(ms)

}
