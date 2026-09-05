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

    use Db.Laps.Columns
    use Db.Schema
    use Sql.Sel
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
        Sql.intoRow(lap -> lapTime -> sum -> blanks ->
            Violation.SectorSum(lap, duration(lapTime), duration(sum), splitLabels(blanks)))
            |> Sql.pipeline(lapOf())
            |> Sql.pipeline(Sql.int("lap_time_ms"))
            |> Sql.pipeline(Sql.int("COALESCE(s1_ms,0) + COALESCE(s2_ms,0) + COALESCE(s3_ms,0)"))
            |> Sql.pipeline(Sql.text(
                "TRIM("
                    + "   CASE WHEN s1_ms IS NULL THEN 's1,' ELSE '' END ||"
                    + "   CASE WHEN s2_ms IS NULL THEN 's2,' ELSE '' END ||"
                    + "   CASE WHEN s3_ms IS NULL THEN 's3,' ELSE '' END, ',')"
            ))
            |> Sql.selectAll(Sql.frags(
                Sql.raw("FROM laps WHERE") ::
                where_(entry, Sql.ne(
                    Sql.column("COALESCE(s1_ms,0) + COALESCE(s2_ms,0) + COALESCE(s3_ms,0)"),
                    Columns.expr(Columns.lapTimeMs())
                ) :: Nil) ::
                Sql.raw("ORDER BY source_row") :: Nil
            ))

    def elapsedDriftViolations(entry: Entry): Result[String, List[Violation]] \ Db =
        Sql.intoRow(lap -> expected -> actual ->
            Violation.ElapsedDrift(lap, duration(expected), duration(actual)))
            |> Sql.pipeline(lapOf())
            |> Sql.pipeline(Sql.int("running"))
            |> Sql.pipeline(Sql.int("elapsed_ms"))
            |> Sql.selectAllWith(
                Sql.frags(
                    Sql.raw("WITH c AS (SELECT car_number, lap_number, elapsed_ms,"
                        + " SUM(lap_time_ms) OVER (PARTITION BY car_number ORDER BY lap_number) AS running,"
                        + " MIN(source_row) OVER (PARTITION BY car_number) AS first_seen"
                        + " FROM laps WHERE") ::
                    where_(entry, Nil) ::
                    Sql.raw(")") :: Nil
                ),
                Sql.raw("FROM c WHERE running <> elapsed_ms ORDER BY first_seen, lap_number")
            )

    def hourOffsetViolations(entry: Entry): Result[String, List[Violation]] \ Db =
        Sql.intoRow(lap -> base -> actual -> Violation.HourElapsedOffset(lap, base, actual))
            |> Sql.pipeline(lapOf())
            |> Sql.pipeline(Sql.int("base"))
            |> Sql.pipeline(Sql.int("off"))
            |> Sql.selectAllWith(
                Sql.frags(
                    Sql.raw("WITH o AS (SELECT car_number, lap_number, source_row, "
                        + Schema.hourOffset() + " AS off,"
                        + " FIRST_VALUE(" + Schema.hourOffset() + ") OVER (ORDER BY source_row) AS base"
                        + " FROM laps WHERE") ::
                    where_(entry, Nil) ::
                    Sql.raw(")") :: Nil
                ),
                Sql.raw("FROM o WHERE off <> base ORDER BY source_row")
            )

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
        Sql.intoRow(lap -> sourceRow -> lapTime -> sum -> ids ->
            (sourceRow, 0, Violation.MiniSectorSum(lap, duration(lapTime), duration(sum), ids)))
            |> Sql.pipeline(lapOf())
            |> Sql.pipeline(Sql.int("source_row"))
            |> Sql.pipeline(Sql.int("lap_time_ms"))
            |> Sql.pipeline(Sql.int("sum_ms"))
            |> Sql.pipeline(Sql.text("blanks") |> Sql.andThen(positions))
            |> Sql.selectAllWith(
                Sql.frags(
                    Sql.raw("WITH m AS (SELECT car_number, lap_number, source_row, lap_time_ms,"
                        + " crossing_finish_line_in_pit, pit_time_ms,"
                        + " (SELECT COALESCE(SUM(t.value), 0)"
                        + "  FROM json_each(laps.mini_sector_time_ms) t) AS sum_ms,"
                        + " COALESCE((SELECT GROUP_CONCAT(t.key + 1, ',' ORDER BY t.key)"
                        + "  FROM json_each(laps.mini_sector_time_ms) t"
                        + "  WHERE t.value IS NULL), '') AS blanks"
                        + " FROM laps WHERE") ::
                    where_(entry, Sql.isNotNull(Columns.expr(Columns.miniSectorTimeMs())) :: Nil) ::
                    Sql.raw(")") :: Nil
                ),
                Sql.raw("FROM m WHERE NOT (crossing_finish_line_in_pit = 1 OR pit_time_ms IS NOT NULL)"
                    + " AND sum_ms <> lap_time_ms"
                    + trackLimitsExclusions()
                    + " ORDER BY source_row")
            )

    def miniSectorMonotonicViolations(entry: Entry): Result[String, List[(Int32, Int32, Violation)]] \ Db =
        monotonicBreak()
            |> Sql.selectAllWith(
                Sql.frags(
                    Sql.raw("WITH e AS (SELECT car_number, lap_number, source_row,"
                        + " x.key + 1 AS ord, x.value AS v,"
                        + " LAG(x.key + 1) OVER w AS prev_ord, LAG(x.value) OVER w AS prev_v"
                        + " FROM laps, json_each(laps.mini_sector_elapsed_ms) x"
                        + " WHERE") ::
                    where_(entry,
                        Sql.isNotNull(Columns.expr(Columns.miniSectorElapsedMs())) ::
                        Sql.isNotNull(Sql.column("x.value")) :: Nil) ::
                    Sql.raw("WINDOW w AS (PARTITION BY source_row ORDER BY x.key))") :: Nil
                ),
                Sql.raw("FROM e WHERE prev_v IS NOT NULL AND v <= prev_v ORDER BY source_row, ord")
            )

    def monotonicBreak(): Sel[(Int32, Int32, Violation)] =
        Sql.intoRow(lap -> sourceRow -> prevId -> prevElapsed -> ord -> currId -> elapsed ->
            (sourceRow, ord, Violation.MiniSectorElapsedMonotonic(
                lap, prevId, duration(prevElapsed), currId, duration(elapsed))))
            |> Sql.pipeline(lapOf())
            |> Sql.pipeline(Sql.int("source_row"))
            |> Sql.pipeline(Sql.int("prev_ord") |> Sql.andThen(miniSectorAt))
            |> Sql.pipeline(Sql.int("prev_v"))
            |> Sql.pipeline(Sql.int("ord"))
            |> Sql.pipeline(Sql.int("ord") |> Sql.andThen(miniSectorAt))
            |> Sql.pipeline(Sql.int("v"))

    // ------------------------------------------------------------------- sql

    def scope(entry: Entry): Sql.Expr[Bool] =
        Schema.scope(entry#season, entry#id)

    /// The round's rows, and whatever else the rule asks of them.
    def where_(entry: Entry, predicates: List[Sql.Expr[Bool]]): Sql.Frag =
        Sql.predicate(Sql.every(scope(entry) :: predicates))

    /// Built from `Motorsport.MiniSector` rather than written out, so the
    /// signatures are named in one place and the positions follow track order.
    def trackLimitsExclusions(): String =
        MiniSector.trackLimitsSignatures()
            |> List.map(signature ->
                " AND blanks <> '"
                    + (signature |> List.map(id -> "${MiniSector.positionOf(id)}") |> List.join(","))
                    + "'"
            )
            |> List.join("")

    // ---------------------------------------------------------------- decode

    def lapOf(): Sel[Lap] =
        Sql.intoRow(carNumber -> lapNumber -> { carNumber = carNumber, lapNumber = lapNumber })
            |> Sql.pipeline(Sql.text("car_number"))
            |> Sql.pipeline(Sql.int("lap_number"))

    def duration(ms: Int32): Duration =
        Util.Duration.fromMillis(ms)

    def splitLabels(joined: String): List[String] =
        if (String.isEmpty(joined)) Nil else String.splitOn({substr = ","}, joined)

    def positions(joined: String): Result[String, List[MiniSectorId]] =
        splitLabels(joined) |> Result.traverse(text ->
            forM(
                position <- Int32.fromString(text) |> Option.toOk("not a position: \"${text}\"");
                id       <- miniSectorAt(position)
            ) yield id
        )

    def miniSectorAt(position: Int32): Result[String, MiniSectorId] =
        MiniSector.atPosition(position)
            |> Option.toOk("no mini-sector at position ${position}")

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
