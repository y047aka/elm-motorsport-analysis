pub mod Sql.TestQuery {
    use Lite3fx.SqlValue

    use Db.Laps
    use Db.Schema

    def laps(): Sql.Rows[Laps.Columns] =
        Sql.access(Sql.raw("laps"), Laps.columns())
            |> Sql.filter(c -> Sql.eq(Schema.expr(c#roundId), Sql.i32(3)))

    def lapNumbers(): Sql.Sel[Int32] =
        Sql.int("lap_number")

    @Test
    def theClausesFollowTheOrderSqlWantsThemRatherThanTheOrderTheyWereAsked(): Unit \ Assert =
        let statement = laps()
            |> Sql.orderBy(Schema.term(Laps.columns()#sourceRow) :: Nil)
            |> Sql.groupBy(Schema.term(Laps.columns()#lapNumber) :: Nil)
            |> Sql.map(c -> c#lapNumber)
            |> Sql.toStatement;
        Assert.assertTrue(Sql.toSql(statement) == (
            "SELECT lap_number FROM laps WHERE round_id = ?"
                + " GROUP BY lap_number ORDER BY source_row",
            SqlValue.Int32(3) :: Nil
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
            |> Sql.filter(c -> Sql.isNotNull(Schema.expr(c#s1Ms)))
            |> Sql.limit(1)
            |> Sql.map(_ -> lapNumbers())
            |> Sql.toStatement;
        Assert.assertTrue(Sql.toSql(statement) == (
            "SELECT lap_number FROM laps WHERE round_id = ? AND s1_ms IS NOT NULL LIMIT 1",
            SqlValue.Int32(3) :: Nil
        ))

    /// The common table expressions come before the SELECT, and so do the
    /// values they bind. The query writes the `WITH` once however many there
    /// are, so a second one is added rather than replacing the first.
    @Test
    def theCommonTableExpressionsAreJoinedAndTheirValuesComeFirst(): Unit \ Assert =
        let statement = Sql.rows(Sql.raw("c JOIN d ON d.n = c.n"))
            |> Sql.using(Sql.frag("c AS (SELECT 1 AS n FROM laps WHERE round = ?)",
                SqlValue.Str("le_mans_24h") :: Nil))
            |> Sql.using(Sql.frag("d AS (SELECT 2 AS n FROM laps WHERE round = ?)",
                SqlValue.Str("fuji_6h") :: Nil))
            |> Sql.filter(_ -> Sql.eq(Sql.column("season"), Sql.i32(2025)))
            |> Sql.map(_ -> lapNumbers())
            |> Sql.toStatement;
        Assert.assertTrue(Sql.toSql(statement) == (
            "WITH c AS (SELECT 1 AS n FROM laps WHERE round = ?),"
                + " d AS (SELECT 2 AS n FROM laps WHERE round = ?)"
                + " SELECT lap_number FROM c JOIN d ON d.n = c.n WHERE season = ?",
            SqlValue.Str("le_mans_24h") :: SqlValue.Str("fuji_6h") :: SqlValue.Int32(2025) :: Nil
        ))

}
