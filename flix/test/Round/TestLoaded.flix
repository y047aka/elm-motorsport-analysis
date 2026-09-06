mod Round.TestLoaded {

    use Db.TestLapRow
    use Motorsport.Calendar.Entry
    use Round.TestSupport

    def fuji(): Entry = { season = 2025, id = "fuji_6h", date = "2025-09-28" }

    @Test
    def aRoundInBothTablesIsLoaded(): Unit \ {Assert, IO} =
        Assert.assertTrue(
            TestSupport.onRound(fuji(), TestLapRow.sampleLaps(), () -> Round.loaded(fuji()))
        )

    @Test
    def aRoundNoRunHasLoadedIsNot(): Unit \ {Assert, IO} =
        Assert.assertTrue(
            not TestSupport.onRound(fuji(), Nil, () -> Round.loaded(fuji()))
        )

    /// The laps alone would answer as a race whose grid was empty rather than
    /// as one that never ran.
    @Test
    def aRoundWithLapsAndNoCarsIsNot(): Unit \ {Assert, IO} =
        Assert.assertTrue(
            not TestSupport.onLapsAlone(fuji(), TestLapRow.sampleLaps(), () -> Round.loaded(fuji()))
        )

}
