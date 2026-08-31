mod Cli.Db.TestSchema {

    use Cli.Db.LapRow
    use Cli.Db.Schema
    use Cli.Db.TestLapRow

    /// Neither compiler sees the two lists together: the columns are text and
    /// the values are bound by position, so a column added to one and not the
    /// other fails here or not at all.
    @Test
    def everyColumnHasAValue(): Unit \ Assert =
        let row = LapRow.fromRawLap({ season = 2025, id = "fuji_6h", date = "2025-09-28" })(
            TestLapRow.sampleLap()
        );
        Assert.assertTrue(List.length(Schema.columns()) == List.length(LapRow.values(row)))

    @Test
    def theInsertBindsOnePlaceholderPerColumn(): Unit \ Assert =
        let sql = Schema.insert();
        let placeholders = String.countSubstring({substr = "?"}, sql);
        Assert.assertTrue(placeholders == List.length(Schema.columns()))

    @Test
    def theJsonbColumnIsCastAndNoOtherIs(): Unit \ Assert =
        let sql = Schema.insert();
        Assert.assertTrue(String.countSubstring({substr = "?::jsonb"}, sql) == 1);
        Assert.assertTrue(String.contains({substr = "mini_sectors"}, sql))

    @Test
    def theTableIsKeyedByTheLapItHolds(): Unit \ Assert =
        Assert.assertTrue(String.contains(
            {substr = "PRIMARY KEY (season, round, car_number, lap_number)"},
            Schema.createTable()
        ))

    @Test
    def theRunRebuildsTheTable(): Unit \ Assert =
        Assert.assertTrue(Schema.dropTable() == "DROP TABLE IF EXISTS laps")

}
