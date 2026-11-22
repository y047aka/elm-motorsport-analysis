/// Aggregates and windows are written over a projection and keep its reading, so
/// the check is both halves at once: what the statement says, and what the cell
/// comes back as.
pub mod Sql.TestWindow {

    use Db.Laps
    use Db.Schema
    use Sqlitefx.SqlValue
    use Sql.Frame
    use Sql.Sel

    def columns(): Laps.Columns =
        Laps.columns()

    /// The record's lap time is an `Option`, and so is its minimum: the reading
    /// the column carries is the reading `min` hands back.
    @Test
    def anAggregateOverANullableColumnReadsAsThatColumnReads(): Unit \ Assert =
        let fastest = Sql.min(columns()#s1Ms);
        Assert.assertTrue(Sql.toSql(Sql.fragment(fastest)) == ("MIN(s1_ms)", Nil));
        Assert.assertTrue(Sql.decode(fastest, TestCells.answering(fastest, SqlValue.Int32(61234) :: Nil)) == Ok(Some(61234)))

    /// An aggregate answers under a label of its own, so it never comes back under the name of the column it is over.
    @Test
    def anAggregateIsLabelledForTheFunctionAndItsArgument(): Unit \ Assert =
        Assert.assertTrue(Sql.toSql(Sql.clause(Sql.min(columns()#s1Ms))) == ("SELECT MIN(s1_ms) AS min_s1_ms", Nil))

    @Test
    def countingCounts(): Unit \ Assert =
        Assert.assertTrue(
            Sql.toSql(Sql.fragment(Sql.count(columns()#lapTimeMs))) == ("COUNT(lap_time_ms)", Nil)
        )

    // ------------------------------------------------------------------ frames

    /// The frame the running minima use, spelled once.
    @Test
    def theFrameReachingEveryRowBeforeThisOne(): Unit \ Assert =
        let frame = Sql.rowsBetween(Frame.UnboundedPreceding, Frame.Preceding(1));
        Assert.assertTrue(frame == Some("ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING"))

    @Test
    def theFrameReachingEveryRowOfThePartitionUpToThisOne(): Unit \ Assert =
        let frame = Sql.rowsBetween(Frame.UnboundedPreceding, Frame.CurrentRow);
        Assert.assertTrue(frame == Some("ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW"))

    // ------------------------------------------------------------------ windows

    def standing(): Sel[String] =
        Sql.over(
            Sql.min(Sql.text("t")),
            Sql.window(
                "k" :: Nil,
                Schema.name(columns()#elapsedMs) :: Schema.name(columns()#sourceRow) :: Nil,
                Sql.rowsBetween(Frame.UnboundedPreceding, Frame.Preceding(1))
            )
        )

    @Test
    def aWindowNamesItsPartitionItsOrderAndItsFrameInThatOrder(): Unit \ Assert =
        Assert.assertTrue(
            Sql.toSql(Sql.fragment(standing())) == (
                "MIN(t) OVER (PARTITION BY k ORDER BY elapsed_ms, source_row"
                    + " ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)",
                Nil
            )
        )

    /// A window with nothing to say is `OVER ()`, not an empty pair of
    /// parentheses' worth of clauses.
    @Test
    def aWindowAskingNothingCarriesNoPartitionAndNoOrder(): Unit \ Assert =
        let first = Sql.rowNumber(Sql.window(Nil, Schema.name(columns()#sourceRow) :: Nil, None));
        Assert.assertTrue(
            Sql.toSql(Sql.fragment(first)) == ("ROW_NUMBER() OVER (ORDER BY source_row)", Nil)
        )

    /// A named window is spelled in the clause and referred to everywhere else,
    /// which is how fifteen running minima are written once.
    @Test
    def aWindowTheQueryNamesIsReferredToRatherThanRepeated(): Unit \ Assert =
        let car = Sql.namedWindow(
            "w",
            Schema.name(columns()#carNumber) :: Nil,
            Schema.name(columns()#lapNumber) :: Nil,
            Sql.rowsBetween(Frame.UnboundedPreceding, Frame.CurrentRow)
        );
        Assert.assertTrue(Sql.toSql(Sql.fragment(Sql.over(Sql.min(columns()#s1Ms), car))) == (
            "MIN(s1_ms) OVER w", Nil
        ));
        Assert.assertTrue(Option.map(Sql.toSql, Sql.windowClause(car)) == Some((
            "WINDOW w AS (PARTITION BY car_number ORDER BY lap_number"
                + " ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)",
            Nil
        )))

    /// The name is what tells the two spellings apart, so an unnamed window
    /// contributes no `WINDOW` clause at all.
    @Test
    def aWindowNobodyNamedContributesNoWindowClause(): Unit \ Assert =
        Assert.assertTrue(
            Option.map(Sql.toSql, Sql.windowClause(Sql.window(Nil, Schema.name(columns()#sourceRow) :: Nil, None))) == None
        )

    // ------------------------------------------------------------- predecessors

    /// The first row of a window has no predecessor, and the null answering that
    /// is a reading rather than a failure.
    @Test
    def thePredecessorTheFirstRowHasNotIsNothingRatherThanAFailedReading(): Unit \ Assert =
        let prior = Sql.lag(columns()#flagAtFl, Sql.window(
            Nil, Schema.name(columns()#elapsedMs) :: Nil, None
        ));
        Assert.assertTrue(Sql.toSql(Sql.fragment(prior)) == (
            "LAG(flag_at_fl) OVER (ORDER BY elapsed_ms)", Nil
        ));
        Assert.assertTrue(Sql.decode(prior, TestCells.answering(prior, SqlValue.Null :: Nil)) == Ok(None));
        Assert.assertTrue(Sql.decode(prior, TestCells.answering(prior, SqlValue.Str("SF") :: Nil)) == Ok(Some("SF")))

    /// The maximum over no rows is the other thing `opt` is for.
    @Test
    def anAggregateOverNoRowsReadsAsNothing(): Unit \ Assert =
        let laps = Sql.opt(Sql.max(columns()#elapsedMs));
        Assert.assertTrue(Sql.toSql(Sql.fragment(laps)) == ("MAX(elapsed_ms)", Nil));
        Assert.assertTrue(Sql.decode(laps, TestCells.answering(laps, SqlValue.Null :: Nil)) == Ok(None));
        Assert.assertTrue(Sql.decode(laps, TestCells.answering(laps, SqlValue.Int32(5400000) :: Nil)) == Ok(Some(5400000)))

    @Test
    def theStandingFlagIsTheGreenTheRaceStartsOnWhereThereIsNoPredecessor(): Unit \ Assert =
        let prior = Sql.lag(columns()#flagAtFl, Sql.window(
            Nil, Schema.name(columns()#elapsedMs) :: Nil, None
        ));
        Assert.assertTrue(
            Sql.toSql(Sql.fragment(Sql.coalesce(prior, Sql.text("'Green'")))) == (
                "COALESCE(LAG(flag_at_fl) OVER (ORDER BY elapsed_ms), 'Green')", Nil
            )
        )

    @Test
    def nothingAskedOfTheFlagIsTheStartOfTheRace(): Unit \ Assert =
        Assert.assertTrue(
            Sql.toSql(Sql.term(Sql.isNull(Sql.column("prior")))) == ("prior IS NULL", Nil)
        )

}
