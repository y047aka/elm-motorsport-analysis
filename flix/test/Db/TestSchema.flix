mod Db.TestSchema {

    use Db.LapRow
    use Db.Schema
    use Db.TestLapRow

    /// Neither compiler sees the two lists together: the columns are text and
    /// the values are bound by position, so a column added to one and not the
    /// other fails here or not at all.
    @Test
    def everyColumnHasAValue(): Unit \ Assert =
        let row = LapRow.fromRawLap(
            { season = 2025, id = "fuji_6h", date = "2025-09-28" }, 1, TestLapRow.sampleLap()
        );
        Assert.assertTrue(List.length(Schema.columns()) == List.length(LapRow.values(row)))

    /// The load names the columns and the reading names them again, and no
    /// compiler sees the two lists together either.
    @Test
    def theReadingNamesTheColumnsTheLoadBound(): Unit \ Assert =
        Assert.assertTrue(
            Sql.clause(LapRow.selection()) == "SELECT " + List.join(", ", Schema.columns())
        )

    @Test
    def theInsertBindsOnePlaceholderPerColumn(): Unit \ Assert =
        let sql = Schema.insert();
        let placeholders = String.countSubstring({substr = "?"}, sql);
        Assert.assertTrue(placeholders == List.length(Schema.columns()))

}
