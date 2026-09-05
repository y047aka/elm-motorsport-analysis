mod Sql.TestQuery {

    use Db.Laps
    use Db.Value

    def laps(): Sql.Rows[Laps.Columns] =
        Laps.rows()
            |> Sql.filter(Sql.eq(Laps.expr(Laps.columns()#season), Sql.i32(2025)))

    def lapNumbers(): Sql.Sel[Int32] =
        Sql.int("lap_number")

    @Test
    def theClausesFollowTheOrderSqlWantsThemRatherThanTheOrderTheyWereAsked(): Unit \ Assert =
        let statement = laps()
            |> Sql.orderBy(Laps.term(Laps.columns()#sourceRow) :: Nil)
            |> Sql.groupBy(Laps.term(Laps.columns()#lapNumber) :: Nil)
            |> Sql.map(c -> c#lapNumber)
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
        let statement = Sql.rows(Sql.raw("laps")) |> Sql.map(_ -> lapNumbers()) |> Sql.toStatement;
        Assert.assertTrue(Sql.toSql(statement) == ("SELECT lap_number FROM laps", Nil))

    @Test
    def askingTwiceAsksBoth(): Unit \ Assert =
        let statement = laps()
            |> Sql.filter(Sql.isNotNull(Laps.expr(Laps.columns()#s1Ms)))
            |> Sql.limit(1)
            |> Sql.map(_ -> lapNumbers())
            |> Sql.toStatement;
        Assert.assertTrue(Sql.toSql(statement) == (
            "SELECT lap_number FROM laps WHERE season = ? AND s1_ms IS NOT NULL LIMIT 1",
            Value.Integer(2025) :: Nil
        ))

    /// The common table expressions come before the SELECT, and so do the
    /// values they bind. The query writes the `WITH` once however many there
    /// are, so a second one is added rather than replacing the first.
    @Test
    def theCommonTableExpressionsAreJoinedAndTheirValuesComeFirst(): Unit \ Assert =
        let statement = Sql.rows(Sql.raw("c JOIN d ON d.n = c.n"))
            |> Sql.using(Sql.frag("c AS (SELECT 1 AS n FROM laps WHERE round = ?)",
                Value.Text("le_mans_24h") :: Nil))
            |> Sql.using(Sql.frag("d AS (SELECT 2 AS n FROM laps WHERE round = ?)",
                Value.Text("fuji_6h") :: Nil))
            |> Sql.filter(Sql.eq(Sql.column("season"), Sql.i32(2025)))
            |> Sql.map(_ -> lapNumbers())
            |> Sql.toStatement;
        Assert.assertTrue(Sql.toSql(statement) == (
            "WITH c AS (SELECT 1 AS n FROM laps WHERE round = ?),"
                + " d AS (SELECT 2 AS n FROM laps WHERE round = ?)"
                + " SELECT lap_number FROM c JOIN d ON d.n = c.n WHERE season = ?",
            Value.Text("le_mans_24h") :: Value.Text("fuji_6h") :: Value.Integer(2025) :: Nil
        ))

}
