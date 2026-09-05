mod Sql.TestQuery {

    use Db.Laps.Columns
    use Db.Value

    def laps(): Sql.Rows =
        Sql.rows(Sql.raw("laps"))
            |> Sql.filter(Sql.eq(Columns.expr(Columns.season()), Sql.i32(2025)))

    def lapNumbers(): Sql.Sel[Int32] =
        Sql.int("lap_number")

    @Test
    def theClausesFollowTheOrderSqlWantsThemRatherThanTheOrderTheyWereAsked(): Unit \ Assert =
        let statement = laps()
            |> Sql.orderBy(Columns.term(Columns.sourceRow()) :: Nil)
            |> Sql.groupBy(Columns.term(Columns.lapNumber()) :: Nil)
            |> Sql.map(lapNumbers())
            |> Sql.toStatement;
        Assert.assertTrue(Sql.toSql(statement) == (
            "SELECT lap_number FROM laps WHERE season = ?"
                + " GROUP BY lap_number ORDER BY source_row",
            Value.Integer(2025) :: Nil
        ))

    /// A clause with nothing to say is left out, since `WHERE` with nothing
    /// after it is not a query.
    @Test
    def aQueryAskingNothingCarriesNoWhere(): Unit \ Assert =
        let statement = Sql.rows(Sql.raw("laps")) |> Sql.map(lapNumbers()) |> Sql.toStatement;
        Assert.assertTrue(Sql.toSql(statement) == ("SELECT lap_number FROM laps", Nil))

    @Test
    def askingTwiceAsksBoth(): Unit \ Assert =
        let statement = laps()
            |> Sql.filter(Sql.isNotNull(Columns.expr(Columns.s1Ms())))
            |> Sql.limit(1)
            |> Sql.map(lapNumbers())
            |> Sql.toStatement;
        Assert.assertTrue(Sql.toSql(statement) == (
            "SELECT lap_number FROM laps WHERE season = ? AND s1_ms IS NOT NULL LIMIT 1",
            Value.Integer(2025) :: Nil
        ))

    /// The common table expressions come before the SELECT, and so do the
    /// values they bind.
    @Test
    def theCommonTableExpressionsValuesComeFirst(): Unit \ Assert =
        let statement = Sql.rows(Sql.raw("c"))
            |> Sql.using(Sql.frag("WITH c AS (SELECT 1 FROM laps WHERE round = ?)",
                Value.Text("le_mans_24h") :: Nil))
            |> Sql.filter(Sql.eq(Sql.column("season"), Sql.i32(2025)))
            |> Sql.map(lapNumbers())
            |> Sql.toStatement;
        Assert.assertTrue(Sql.toSql(statement) == (
            "WITH c AS (SELECT 1 FROM laps WHERE round = ?)"
                + " SELECT lap_number FROM c WHERE season = ?",
            Value.Text("le_mans_24h") :: Value.Integer(2025) :: Nil
        ))

}
