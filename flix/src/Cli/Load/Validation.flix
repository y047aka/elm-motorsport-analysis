/// Source-data integrity checks, run against the rows the round was just
/// loaded into rather than against the laps in memory. Violations are warnings
/// only; they do not affect the exit code. `Cli.Load` prints them to stderr.
///
/// Rules:
///   1. SectorSum                  — `s1 + s2 + s3 == lapTime` (per row)
///   2. ElapsedDrift               — per car, `elapsed[n] == sum(lapTime[1..=n])`
///                                   (cumulative-sum: every row from the first drift
///                                   onward is reported)
///   3. HourElapsedOffset          — across the round, `(hour - elapsed) mod 24h` is
///                                   constant
///   4. MiniSectorSum              — when mini-sectors present, `sum(time) == lapTime`
///                                   (blank `time` counted as zero).
///                                   Skipped on pit laps and Ford-chicane track-limits
///                                   signatures.
///   5. MiniSectorElapsedMonotonic — when mini-sectors present, `elapsed` values are
///                                   strictly increasing in track order. Equality is
///                                   reported (two timing loops cannot fire at the
///                                   same millisecond). Always run, even on pit laps.
///
/// Design notes:
///   - HourElapsedOffset's baseline is the **first row of the whole file**
///     (round-wide, not per-car), which is what `source_row` is in the table
///     for. A bad lap 1 on one car does not cascade across the rest of that car.
///   - 24h wrap is folded into the offset expression, so the rule compares
///     offsets with `=`.
///   - Report order follows the file's order within each rule, and the rules
///     follow the order above -- except that a lap's mini-sector violations are
///     reported together, its sum before its monotonic breaks.
///   - **MiniSectorSum pit-lap skip** — pit-entry laps bypass main-line
///     markers (typically FORDOUT and FL_time) so the sum can never reach
///     lapTime. Identified by `crossing_finish_line_in_pit` or a `pit_time_ms`.
///   - **MiniSectorSum track-limits skip** — running off the Ford chicanes
///     leaves a known blank pattern, `Motorsport.MiniSector.trackLimitsSignatures`.
///     These are the dominant non-pit cause of residual sum mismatches in
///     Le Mans 2025.
mod Cli.Load.Validation {

    use Db.Row
    use Db.Schema
    use Motorsport.Calendar.Entry
    use Motorsport.MiniSector
    use Motorsport.MiniSector.MiniSectorId
    use Util.Duration.Duration

    /// Which lap a violation is about. The rows carry no more of one than the
    /// report names.
    pub type alias Lap = {
        carNumber = String,
        lapNumber = Int32
    }

    pub enum Violation {
        /// Args: lap / lapTime / sector sum / labels of blank sectors.
        case SectorSum(Lap, Duration, Duration, List[String])

        /// Args: lap / expected = running sum / actual = elapsed.
        case ElapsedDrift(Lap, Duration, Duration)

        /// Args: lap / baseline offset ms / actual offset ms.
        case HourElapsedOffset(Lap, Int32, Int32)

        /// Args: lap / lapTime / sum / IDs of sub-sectors with blank time,
        /// in track order.
        case MiniSectorSum(Lap, Duration, Duration, List[MiniSectorId])

        /// Args: lap / prev id / prev elapsed / curr id / curr elapsed.
        case MiniSectorElapsedMonotonic(Lap, MiniSectorId, Duration, MiniSectorId, Duration)
    }

    pub def validate(entry: Entry): Result[String, List[String]] \ Db =
        detect(entry) |> Result.map(List.map(formatViolation(entry#id)))

    pub def detect(entry: Entry): Result[String, List[Violation]] \ Db =
        forM(
            sectorSum <- sectorSumViolations(entry);
            drift     <- elapsedDriftViolations(entry);
            hour      <- hourOffsetViolations(entry);
            mini      <- miniSectorViolations(entry)
        ) yield List.append(sectorSum, List.append(drift, List.append(hour, mini)))

    // ------------------------------------------------------------------ rules

    def sectorSumViolations(entry: Entry): Result[String, List[Violation]] \ Db =
        Db.fetch(
            "SELECT car_number, lap_number, lap_time_ms,"
                + " COALESCE(s1_ms,0) + COALESCE(s2_ms,0) + COALESCE(s3_ms,0),"
                + " ARRAY_TO_STRING(ARRAY_REMOVE(ARRAY["
                + "   CASE WHEN s1_ms IS NULL THEN 's1' END,"
                + "   CASE WHEN s2_ms IS NULL THEN 's2' END,"
                + "   CASE WHEN s3_ms IS NULL THEN 's3' END], NULL), ',')"
                + " FROM laps WHERE " + scope(entry)
                + " AND COALESCE(s1_ms,0) + COALESCE(s2_ms,0) + COALESCE(s3_ms,0) <> lap_time_ms"
                + " ORDER BY source_row"
        ) |> Result.flatMap(Result.traverse(row ->
            forM(
                lap      <- lapOf(row);
                lapTime  <- Row.int(2, row);
                sum      <- Row.int(3, row);
                blanks   <- Row.text(4, row)
            ) yield Violation.SectorSum(lap, duration(lapTime), duration(sum), splitLabels(blanks))
        ))

    def elapsedDriftViolations(entry: Entry): Result[String, List[Violation]] \ Db =
        Db.fetch(
            "WITH c AS (SELECT car_number, lap_number, elapsed_ms,"
                + " (SUM(lap_time_ms) OVER (PARTITION BY car_number ORDER BY lap_number))::int AS running,"
                + " MIN(source_row) OVER (PARTITION BY car_number) AS first_seen"
                + " FROM laps WHERE " + scope(entry) + ")"
                + " SELECT car_number, lap_number, running, elapsed_ms FROM c"
                + " WHERE running <> elapsed_ms ORDER BY first_seen, lap_number"
        ) |> Result.flatMap(Result.traverse(row ->
            forM(
                lap      <- lapOf(row);
                expected <- Row.int(2, row);
                actual   <- Row.int(3, row)
            ) yield Violation.ElapsedDrift(lap, duration(expected), duration(actual))
        ))

    def hourOffsetViolations(entry: Entry): Result[String, List[Violation]] \ Db =
        Db.fetch(
            "WITH o AS (SELECT car_number, lap_number, source_row, " + Schema.hourOffset() + " AS off,"
                + " FIRST_VALUE(" + Schema.hourOffset() + ") OVER (ORDER BY source_row) AS base"
                + " FROM laps WHERE " + scope(entry) + ")"
                + " SELECT car_number, lap_number, base, off FROM o"
                + " WHERE off <> base ORDER BY source_row"
        ) |> Result.flatMap(Result.traverse(row ->
            forM(
                lap    <- lapOf(row);
                base   <- Row.int(2, row);
                actual <- Row.int(3, row)
            ) yield Violation.HourElapsedOffset(lap, base, actual)
        ))

    /// A lap's two mini-sector rules are reported together, so they are read
    /// back tagged with the row they came from and merged on it.
    def miniSectorViolations(entry: Entry): Result[String, List[Violation]] \ Db =
        forM(
            sums <- miniSectorSumViolations(entry);
            mono <- miniSectorMonotonicViolations(entry)
        ) yield
            List.append(sums, mono)
                |> List.sortBy(entry2 -> match entry2 { case (sourceRow, ord, _) => (sourceRow, ord) })
                |> List.map(entry2 -> match entry2 { case (_, _, violation) => violation })

    def miniSectorSumViolations(entry: Entry): Result[String, List[(Int32, Int32, Violation)]] \ Db =
        Db.fetch(
            "WITH m AS (SELECT car_number, lap_number, source_row, lap_time_ms,"
                + " crossing_finish_line_in_pit, pit_time_ms,"
                + " (SELECT COALESCE(SUM(t), 0) FROM UNNEST(mini_sector_time_ms) t)::int AS sum_ms,"
                + " COALESCE((SELECT ARRAY_AGG(ord::int ORDER BY ord)"
                + "  FROM UNNEST(mini_sector_time_ms) WITH ORDINALITY u(t, ord)"
                + "  WHERE t IS NULL), '{}'::int[]) AS blanks"
                + " FROM laps WHERE " + scope(entry) + " AND mini_sector_time_ms IS NOT NULL)"
                + " SELECT car_number, lap_number, source_row, lap_time_ms, sum_ms,"
                + " ARRAY_TO_STRING(blanks, ',') FROM m"
                + " WHERE NOT (crossing_finish_line_in_pit OR pit_time_ms IS NOT NULL)"
                + " AND sum_ms <> lap_time_ms"
                + trackLimitsExclusions()
                + " ORDER BY source_row"
        ) |> Result.flatMap(Result.traverse(row ->
            forM(
                lap       <- lapOf(row);
                sourceRow <- Row.int(2, row);
                lapTime   <- Row.int(3, row);
                sum       <- Row.int(4, row);
                blanks    <- Row.text(5, row);
                ids       <- positions(blanks)
            ) yield (sourceRow, 0, Violation.MiniSectorSum(lap, duration(lapTime), duration(sum), ids))
        ))

    def miniSectorMonotonicViolations(entry: Entry): Result[String, List[(Int32, Int32, Violation)]] \ Db =
        Db.fetch(
            "WITH e AS (SELECT car_number, lap_number, source_row, ord, v,"
                + " LAG(ord) OVER w AS prev_ord, LAG(v) OVER w AS prev_v"
                + " FROM laps, UNNEST(mini_sector_elapsed_ms) WITH ORDINALITY u(v, ord)"
                + " WHERE " + scope(entry) + " AND mini_sector_elapsed_ms IS NOT NULL AND v IS NOT NULL"
                + " WINDOW w AS (PARTITION BY source_row ORDER BY ord))"
                + " SELECT car_number, lap_number, source_row, prev_ord::int, prev_v, ord::int, v"
                + " FROM e WHERE prev_v IS NOT NULL AND v <= prev_v ORDER BY source_row, ord"
        ) |> Result.flatMap(Result.traverse(row ->
            forM(
                lap         <- lapOf(row);
                sourceRow   <- Row.int(2, row);
                prevOrd     <- Row.int(3, row);
                prevElapsed <- Row.int(4, row);
                ord         <- Row.int(5, row);
                elapsed     <- Row.int(6, row);
                prevId      <- miniSectorAt(prevOrd);
                currId      <- miniSectorAt(ord)
            ) yield (sourceRow, ord, Violation.MiniSectorElapsedMonotonic(lap, prevId, duration(prevElapsed), currId, duration(elapsed)))
        ))

    // ------------------------------------------------------------------- sql

    def scope(entry: Entry): String =
        Schema.scope(entry#season, entry#id)

    /// Built from `Motorsport.MiniSector` rather than written out, so the
    /// signatures are named in one place and the positions follow track order.
    def trackLimitsExclusions(): String =
        MiniSector.trackLimitsSignatures()
            |> List.map(signature ->
                " AND blanks <> '{"
                    + (signature |> List.map(id -> "${MiniSector.positionOf(id)}") |> List.join(","))
                    + "}'::int[]"
            )
            |> List.join("")

    // ---------------------------------------------------------------- decode

    def lapOf(row: List[Option[String]]): Result[String, Lap] =
        forM(
            carNumber <- Row.text(0, row);
            lapNumber <- Row.int(1, row)
        ) yield { carNumber = carNumber, lapNumber = lapNumber }

    def duration(ms: Int32): Duration =
        Util.Duration.fromMillis(ms)

    def splitLabels(joined: String): List[String] =
        if (String.isEmpty(joined)) Nil else String.splitOn({substr = ","}, joined)

    def positions(joined: String): Result[String, List[MiniSectorId]] =
        splitLabels(joined) |> Result.traverse(text ->
            forM(
                position <- Int32.fromString(text) |> Row.expect("not a position: \"${text}\"");
                id       <- miniSectorAt(position)
            ) yield id
        )

    def miniSectorAt(position: Int32): Result[String, MiniSectorId] =
        MiniSector.atPosition(position)
            |> Row.expect("no mini-sector at position ${position}")

    // ---------------------------------------------------------------- format

    def formatViolation(eventName: String): Violation -> String =
        v -> match v {
            case Violation.SectorSum(lap, lapTime, sum, blanks) =>
                formatDurationPair(eventName, lap, "sector-sum", lapTime, sum)
                    + blankSuffix(blanks)
            case Violation.ElapsedDrift(lap, expected, actual) =>
                formatDurationPair(eventName, lap, "elapsed-drift", expected, actual)
            case Violation.HourElapsedOffset(lap, base, offset) =>
                formatSignedMsPair(eventName, lap, "hour-offset", base, offset)
            case Violation.MiniSectorSum(lap, lapTime, sum, blanks) =>
                formatDurationPair(eventName, lap, "mini-sector-sum", lapTime, sum)
                    + blankSuffix(List.map(MiniSector.jsonKey, blanks))
            case Violation.MiniSectorElapsedMonotonic(lap, prevId, prevElapsed, currId, currElapsed) =>
                let kind = "mini-sector-elapsed[${MiniSector.jsonKey(prevId)}->${MiniSector.jsonKey(currId)}]";
                formatLabelledDurationPair(eventName, lap, kind, "prev", prevElapsed, "curr", currElapsed)
        }

    def blankSuffix(blanks: List[String]): String =
        if (List.isEmpty(blanks)) "" else " (blank: ${List.join(",", blanks)})"

    /// Emits `{eventName}: [car X #N] kind: expected=<fmt> (<ms>ms) actual=<fmt> (<ms>ms)`.
    /// The raw ms is included alongside the formatted duration to keep the
    /// output both human-readable and grep-friendly.
    def formatDurationPair(eventName: String, lap: Lap, kind: String, expected: Duration, actual: Duration): String =
        formatLabelledDurationPair(eventName, lap, kind, "expected", expected, "actual", actual)

    def formatLabelledDurationPair(
        eventName: String,
        lap: Lap,
        kind: String,
        leftLabel: String,
        leftValue: Duration,
        rightLabel: String,
        rightValue: Duration
    ): String =
        "${eventName}: [car ${lap#carNumber} #${lap#lapNumber}] ${kind}: ${leftLabel}=${leftValue} (${Util.Duration.millis(leftValue)}ms) ${rightLabel}=${rightValue} (${Util.Duration.millis(rightValue)}ms)"

    def formatSignedMsPair(eventName: String, lap: Lap, kind: String, expected: Int32, actual: Int32): String =
        "${eventName}: [car ${lap#carNumber} #${lap#lapNumber}] ${kind}: expected=${formatSignedMs(expected)} (${expected}ms) actual=${formatSignedMs(actual)} (${actual}ms)"

    def formatSignedMs(ms: Int32): String =
        if (ms < 0) "-" + Util.Duration.formatMillis(0 - ms)
        else Util.Duration.formatMillis(ms)

}
