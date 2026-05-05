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

    use Util.Duration.Duration
    use Util.HourClock
    use RawLap.RawLap

    pub enum Violation {
        /// `s1 + s2 + s3 != lapTime`.
        /// Args: lap / lapTime / sector sum / labels of blank sectors.
        case SectorSum(RawLap, Duration, Duration, List[String])

        /// `elapsed[n] != sum(lapTime[1..=n])`. Cumulative-sum based, so
        /// every row from the first drift onward is reported (sticky drift).
        /// Args: lap / expected = running sum / actual = elapsed.
        case ElapsedDrift(RawLap, Duration, Duration)

        /// `(hour - elapsed) mod 24h` does not match the baseline.
        /// Args: lap / baseline offset (ms, signed) / actual offset (ms, signed).
        case HourElapsedOffset(RawLap, Int32, Int32)
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
                if (Map.memberOf(lap#car#carNumber, acc)) acc
                else Map.insert(lap#car#carNumber, Map.size(acc), acc),
            Map.empty()
        );
        let grouped = laps |> List.foldLeft(
            (acc, lap) -> Map.insertWith(
                (existing, fresh) -> List.append(fresh, existing),
                lap#car#carNumber,
                lap :: Nil,
                acc
            ),
            Map.empty()
        );
        Map.toList(grouped) |> List.sortBy(entry -> match entry {
            case (car, _) => Map.get(car, firstSeen) |> Option.getWithDefault(0)
        })

    def checkSectorSum(lap: RawLap): Result[Violation, Unit] =
        let lapTime = lap#lapTime;
        let (s1, s1Blank) = sectorOrZero(lap#s1#value, "s1");
        let (s2, s2Blank) = sectorOrZero(lap#s2#value, "s2");
        let (s3, s3Blank) = sectorOrZero(lap#s3#value, "s3");
        let sum = Util.Duration.add(Util.Duration.add(s1, s2), s3);
        if (sum == lapTime) Ok(())
        else
            let blanks = (s1Blank :: s2Blank :: s3Blank :: Nil) |> List.filterMap(x -> x);
            Err(Violation.SectorSum(lap, lapTime, sum, blanks))

    /// Unpacks an Option[Duration] sector. None is treated as zero and the
    /// field name is returned so it can be attached to the violation message.
    def sectorOrZero(sector: Option[Duration], name: String): (Duration, Option[String]) =
        match sector {
            case Some(d) => (d, None)
            case None    => (Util.Duration.zero(), Some(name))
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
                    let newRun  = Util.Duration.add(running, lap#lapTime);
                    let elapsed = lap#elapsed;
                    if (newRun == elapsed) (newRun, acc)
                    else (newRun, Violation.ElapsedDrift(lap, newRun, elapsed) :: acc)
            },
            (Util.Duration.zero(), Nil)
        );
        match folded {
            case (_, acc) => List.reverse(acc)
        }

    /// Race-wide hour-elapsed baseline check. The baseline is the first row
    /// in the CSV.
    def checkHourElapsedRaceWide(laps: List[RawLap]): List[Violation] =
        match laps {
            case Nil         => Nil
            case lap :: _ =>
                let base = HourClock.offsetFrom(lap#hour, Util.Duration.millis(lap#elapsed));
                laps |> List.filterMap(l -> resultToOption(checkHourLine(l, base)))
        }

    def checkHourLine(lap: RawLap, base: Int32): Result[Violation, Unit] =
        let offset = HourClock.offsetFrom(lap#hour, Util.Duration.millis(lap#elapsed));
        if (offset == base) Ok(())
        else Err(Violation.HourElapsedOffset(lap, base, offset))

    def formatViolation(eventName: String, v: Violation): String =
        match v {
            case Violation.SectorSum(lap, lapTime, sum, blanks) =>
                let suffix =
                    if (List.isEmpty(blanks)) ""
                    else " (blank: ${List.join(",", blanks)})";
                formatDurationPair(eventName, lap, "sector-sum", lapTime, sum) + suffix
            case Violation.ElapsedDrift(lap, expected, actual) =>
                formatDurationPair(eventName, lap, "elapsed-drift", expected, actual)
            case Violation.HourElapsedOffset(lap, base, offset) =>
                formatSignedMsPair(eventName, lap, "hour-offset", base, offset)
        }

    /// Emits `{eventName}: [car X #N] kind: expected=<fmt> (<ms>ms) actual=<fmt> (<ms>ms)`.
    /// The raw ms is included alongside the formatted Duration to keep the
    /// output both human-readable and grep-friendly (matches Rust output).
    def formatDurationPair(eventName: String, lap: RawLap, kind: String, expected: Duration, actual: Duration): String =
        "${eventName}: [car ${lap#car#carNumber} #${lap#lapNumber}] ${kind}: expected=${expected} (${Util.Duration.millis(expected)}ms) actual=${actual} (${Util.Duration.millis(actual)}ms)"

    def formatSignedMsPair(eventName: String, lap: RawLap, kind: String, expected: Int32, actual: Int32): String =
        "${eventName}: [car ${lap#car#carNumber} #${lap#lapNumber}] ${kind}: expected=${formatSignedMs(expected)} (${expected}ms) actual=${formatSignedMs(actual)} (${actual}ms)"

    def formatSignedMs(ms: Int32): String =
        if (ms < 0) "-" + Util.Duration.formatMillis(0 - ms)
        else Util.Duration.formatMillis(ms)

}
