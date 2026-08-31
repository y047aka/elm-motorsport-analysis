mod Cli.Db.TestSchema {

    use Cli.Db.LapRow
    use Cli.Db.Schema
    use Cli.Db.TestLapRow

    /// Neither compiler sees the two lists together: the columns are text and
    /// the values are bound by position, so a column added to one and not the
    /// other fails here or not at all.
    @Test
    def everyColumnHasAValue(): Unit \ Assert =
        let row = LapRow.fromRawLap(
            { season = 2025, id = "fuji_6h", date = "2025-09-28" }, 1, TestLapRow.sampleLap()
        );
        Assert.assertTrue(List.length(Schema.columns()) == List.length(LapRow.values(row)))

    @Test
    def theInsertBindsOnePlaceholderPerColumn(): Unit \ Assert =
        let sql = Schema.insert();
        let placeholders = String.countSubstring({substr = "?"}, sql);
        Assert.assertTrue(placeholders == List.length(Schema.columns()))

    @Test
    def theArrayColumnsAreTheOnesCast(): Unit \ Assert =
        let sql = Schema.insert();
        Assert.assertTrue(String.countSubstring({substr = "?::"}, sql) == 2);
        Assert.assertTrue(String.countSubstring({substr = "?::int[]"}, sql) == 2);
        Assert.assertTrue(String.contains({substr = "mini_sector_time_ms"}, sql));
        Assert.assertTrue(String.contains({substr = "mini_sector_elapsed_ms"}, sql))

}
