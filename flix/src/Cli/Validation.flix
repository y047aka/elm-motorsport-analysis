/// Source-data integrity checks run during CSV → JSON conversion.
///
/// All rules use strict 0 ms equality. Violations are returned as warnings
/// only; they do not affect the exit code. Stages.processFile prints them
/// to stderr.
///
/// Rules:
///   1. SectorSum                  — `s1 + s2 + s3 == lapTime` (per row)
///   2. ElapsedDrift               — per car, `elapsed[n] == sum(lapTime[1..=n])`
///                                   (cumulative-sum: every row from the first drift
///                                   onward is reported)
///   3. HourElapsedOffset          — across the CSV, `(hour - elapsed) mod 24h` is
///                                   constant
///   4. MiniSectorSum              — when mini-sectors present, `sum(time) == lapTime`
///                                   (per row, blank `time` counted as zero).
///                                   **Skipped on pit laps** (see below).
///   5. MiniSectorElapsedMonotonic — when mini-sectors present, `elapsed` values are
///                                   strictly increasing in track order (reports each
///                                   adjacent pair where the second value is less than
///                                   or equal to the first). Always run even on pit
///                                   laps — monotonicity is not affected by missing
///                                   markers because blank `elapsed` entries are
///                                   skipped without breaking the chain. Equality is
///                                   treated as a violation: two timing loops cannot
///                                   physically fire at the same millisecond, and the
///                                   real Le Mans 2025 dataset never produces an
///                                   equal-adjacent pair.
///
/// Design notes:
///   - HourElapsedOffset's baseline is the **first valid row in the whole
///     CSV** (race-wide, not per-car). A bad lap 1 on one car does not
///     cascade across the rest of that car.
///   - 24h wrap is folded into `Util.HourClock.offsetFrom`, so the validator
///     just compares offsets with `==`.
///   - Report order follows CSV appearance (per-lap is naturally CSV order;
///     per-car uses first-seen-index to sort the car groups).
///   - Mini-sector rules silently skip laps where `miniSectors == None`
///     (non-Le Mans rounds, or laps where all 30 source columns were blank).
///   - **MiniSectorSum is skipped on pit laps** — when a car enters the pits
///     it bypasses main-line markers (typically FORDOUT and FL_time) so the
///     sum can never reach lapTime. A pit lap is identified by either
///     `crossingFinishLineInPit == "B"` (crossed FL inside the pit lane) or
///     `pitTime != None` (pit-stop duration recorded for this lap).
///   - **MiniSectorSum is also skipped for known Ford-chicane track-limits
///     signatures** — when a driver runs off track at a Ford chicane
///     (track-limits violation), the timing loops inside the bypassed
///     section go untriggered (SCL1 + FORDOUT for the second chicane,
///     PITREF + SCL1 for the first). Empirically (Le Mans 2025) these two
///     adjacent-pair blank patterns are the dominant cause of the remaining
///     non-pit MiniSectorSum noise (310 of 311 warnings after the pit
///     skip), concentrated on the front-running hypercars.
///   - Combined skips (pit lap + track-limits violation) reduce Le Mans
///     2025 noise from 2240 → 1 MiniSectorSum warning while preserving
///     genuine timing-loop anomalies (e.g. a wide moment causing FORDOUT +
///     FL_time to drop while the car was not in the pits).
mod Cli.Validation {

    use Util.Duration.Duration
    use Util.HourClock
    use Motorsport.MiniSector
    use Motorsport.MiniSector.MiniSectorId
    use RawLap.RawLap
    use RawLap.RawMiniSector

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

        /// `sum(miniSector.time) != lapTime` for laps with mini-sector data.
        /// Args: lap / lapTime / sum / IDs of sub-sectors with blank time
        /// (in track order). Carry the `MiniSectorId` rather than its
        /// JSON key so downstream consumers (e.g. `isTrackLimitsPattern`)
        /// stay type-safe; `formatViolation` calls `MiniSector.jsonKey`
        /// at the rendering boundary.
        case MiniSectorSum(RawLap, Duration, Duration, List[MiniSectorId])

        /// Mini-sector `elapsed[i] <= elapsed[i-1]` for some adjacent
        /// pair in track order (only entries where both sides are
        /// present are compared). Equality is reported because two
        /// timing loops cannot physically fire at the same millisecond.
        /// Args: lap / prev id / prev elapsed / curr id / curr elapsed.
        case MiniSectorElapsedMonotonic(RawLap, MiniSectorId, Duration, MiniSectorId, Duration)
    }

    pub def validate(eventName: String, laps: List[RawLap]): List[String] =
        detect(laps) |> List.map(v -> formatViolation(eventName, v))

    pub def detect(laps: List[RawLap]): List[Violation] =
        let perLap = laps |> List.filterMap(lap -> resultToOption(checkSectorSum(lap)));
        let perCar = perCarViolations(laps);
        let perRace = checkHourElapsedRaceWide(laps);
        let perMini = laps |> List.flatMap(checkMiniSectors);
        List.append(perLap, List.append(perCar, List.append(perRace, perMini)))

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

    def sectorOrZero(sector: Option[Duration], name: String): (Duration, Option[String]) =
        match sector {
            case Some(d) => (d, None)
            case None    => (Util.Duration.zero(), Some(name))
        }

    /// Cumulative-sum elapsed-drift check (equivalent to Rust's `scan`).
    /// Each lap updates `running = sum(lapTime[1..=n])` and is flagged if
    /// `elapsed` disagrees. Once a drift starts, every subsequent lap is
    /// reported — noisier than adjacent-diff, but catches compensating
    /// drift.
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
            case Violation.MiniSectorSum(lap, lapTime, sum, blanks) =>
                let suffix =
                    if (List.isEmpty(blanks)) ""
                    else " (blank: ${List.join(",", List.map(MiniSector.jsonKey, blanks))})";
                formatDurationPair(eventName, lap, "mini-sector-sum", lapTime, sum) + suffix
            case Violation.MiniSectorElapsedMonotonic(lap, prevId, prevElapsed, currId, currElapsed) =>
                let kind = "mini-sector-elapsed[${MiniSector.jsonKey(prevId)}->${MiniSector.jsonKey(currId)}]";
                formatLabelledDurationPair(eventName, lap, kind, "prev", prevElapsed, "curr", currElapsed)
        }

    /// Per-lap mini-sector checks. Skipped entirely for laps without
    /// mini-sector data (`miniSectors == None`). Otherwise emits at most
    /// one `MiniSectorSum` plus zero or more `MiniSectorElapsedMonotonic`
    /// violations. The `MiniSectorSum` rule is skipped on pit laps since
    /// the car bypasses some main-line markers (see the module-level
    /// docstring).
    def checkMiniSectors(lap: RawLap): List[Violation] =
        match lap#miniSectors {
            case None       => Nil
            case Some(list) =>
                let sumViol  =
                    if (isPitLap(lap)) Nil
                    else checkMiniSectorSum(lap, list);
                let monoViol = checkMiniSectorMonotonic(lap, list);
                List.append(sumViol, monoViol)
        }

    /// True when the car was either flagged as crossing the finish line
    /// inside the pit lane or had a pit-stop duration recorded for this
    /// lap. Either condition implies the car missed at least one main-line
    /// timing loop, so MiniSectorSum can never balance.
    def isPitLap(lap: RawLap): Bool =
        lap#crossingFinishLineInPit or lap#pitTime != None

    def checkMiniSectorSum(lap: RawLap, list: List[(MiniSectorId, Option[RawMiniSector])]): List[Violation] =
        let folded = list |> List.foldLeft(
            (state, pair) -> match (state, pair) {
                case ((accSum, accBlanks), (id, opt)) =>
                    match opt {
                        case Some(sector) => (Util.Duration.add(accSum, sector#time), accBlanks)
                        case None         => (accSum, id :: accBlanks)
                    }
            },
            (Util.Duration.zero(), Nil)
        );
        match folded {
            case (sum, blanksRev) =>
                let blanks = List.reverse(blanksRev);
                if (sum == lap#lapTime)               Nil
                else if (isTrackLimitsPattern(blanks)) Nil
                else                                  Violation.MiniSectorSum(lap, lap#lapTime, sum, blanks) :: Nil
        }

    /// True when the blank `time`-column set matches a known Ford-chicane
    /// track-limits-violation signature for Le Mans 2025. Track-ordered
    /// list, so SCL1 always precedes FORDOUT and PITREF always precedes
    /// SCL1. Compares `MiniSectorId` directly so a rename of a
    /// `MiniSector.jsonKey` mapping cannot silently drift this rule out
    /// of sync.
    def isTrackLimitsPattern(blanks: List[MiniSectorId]): Bool =
        blanks == MiniSectorId.SCL1 :: MiniSectorId.FORDOUT :: Nil
            or blanks == MiniSectorId.PITREF :: MiniSectorId.SCL1 :: Nil

    /// Walks the track-ordered list and reports each adjacent pair
    /// where the second elapsed is less than *or equal to* the first.
    /// Equality is rejected because two timing loops cannot physically
    /// fire at the same millisecond — the real Le Mans 2025 dataset
    /// never produces an equal-adjacent pair, so the strict check
    /// catches stuck-clock anomalies without adding noise. Entries
    /// with blank elapsed are skipped without breaking the chain (so
    /// we still catch a backwards step that straddles a single missing
    /// marker).
    def checkMiniSectorMonotonic(lap: RawLap, list: List[(MiniSectorId, Option[RawMiniSector])]): List[Violation] =
        let folded = list |> List.foldLeft(
            (state, pair) -> match (state, pair) {
                case ((prev, acc), (id, opt)) =>
                    match opt {
                        case None => (prev, acc)
                        case Some(sector) =>
                            let curr = sector#elapsed;
                            match prev {
                                case None => (Some((id, curr)), acc)
                                case Some((prevId, prevElapsed)) =>
                                    if (curr > prevElapsed)
                                        (Some((id, curr)), acc)
                                    else
                                        (Some((id, curr)),
                                         Violation.MiniSectorElapsedMonotonic(lap, prevId, prevElapsed, id, curr) :: acc)
                            }
                    }
            },
            (None, Nil)
        );
        match folded {
            case (_, acc) => List.reverse(acc)
        }

    /// Emits `{eventName}: [car X #N] kind: expected=<fmt> (<ms>ms) actual=<fmt> (<ms>ms)`.
    /// The raw ms is included alongside the formatted Duration to keep the
    /// output both human-readable and grep-friendly (matches Rust output).
    def formatDurationPair(eventName: String, lap: RawLap, kind: String, expected: Duration, actual: Duration): String =
        formatLabelledDurationPair(eventName, lap, kind, "expected", expected, "actual", actual)

    /// Same shape as `formatDurationPair` but with caller-supplied labels.
    /// Used by `MiniSectorElapsedMonotonic` to emit `prev=/curr=` instead of
    /// `expected=/actual=`, since the comparison is "previous marker vs.
    /// current marker" rather than "what we expected vs. what we observed".
    def formatLabelledDurationPair(
        eventName: String,
        lap: RawLap,
        kind: String,
        leftLabel: String,
        leftValue: Duration,
        rightLabel: String,
        rightValue: Duration
    ): String =
        "${eventName}: [car ${lap#car#carNumber} #${lap#lapNumber}] ${kind}: ${leftLabel}=${leftValue} (${Util.Duration.millis(leftValue)}ms) ${rightLabel}=${rightValue} (${Util.Duration.millis(rightValue)}ms)"

    def formatSignedMsPair(eventName: String, lap: RawLap, kind: String, expected: Int32, actual: Int32): String =
        "${eventName}: [car ${lap#car#carNumber} #${lap#lapNumber}] ${kind}: expected=${formatSignedMs(expected)} (${expected}ms) actual=${formatSignedMs(actual)} (${actual}ms)"

    def formatSignedMs(ms: Int32): String =
        if (ms < 0) "-" + Util.Duration.formatMillis(0 - ms)
        else Util.Duration.formatMillis(ms)

}
