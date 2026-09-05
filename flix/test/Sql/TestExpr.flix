mod Sql.TestExpr {

    use Db.Laps.Columns
    use Db.Schema
    use Db.Value

    @Test
    def aComparisonBindsTheValueItComparesAgainst(): Unit \ Assert =
        let expr = Sql.eq(Columns.expr(Columns.lapNumber()), Sql.i32(1));
        Assert.assertTrue(
            Sql.toSql(Sql.term(expr)) == ("lap_number = ?", Value.Integer(1) :: Nil)
        )

    /// `IS NULL` reads nothing, so it binds nothing.
    @Test
    def aNullTestNamesTheColumnAlone(): Unit \ Assert =
        let expr = Sql.isNotNull(Columns.expr(Columns.miniSectorTimeMs()));
        Assert.assertTrue(
            Sql.toSql(Sql.term(expr)) == ("mini_sector_time_ms IS NOT NULL", Nil)
        )

    @Test
    def predicatesAreAndedInTheOrderGiven(): Unit \ Assert =
        let expr = Sql.every(
            Sql.eq(Columns.expr(Columns.season()), Sql.i32(2025)) ::
            Sql.ne(Columns.expr(Columns.lapTimeMs()), Sql.i32(0)) ::
            Sql.isNotNull(Columns.expr(Columns.s1Ms())) :: Nil
        );
        Assert.assertTrue(Sql.toSql(Sql.term(expr)) == (
            "season = ? AND lap_time_ms <> ? AND s1_ms IS NOT NULL",
            Value.Integer(2025) :: Value.Integer(0) :: Nil
        ))

    @Test
    def nothingAskedOfTheRowsHoldsOfEveryRow(): Unit \ Assert =
        Assert.assertTrue(Sql.toSql(Sql.term(Sql.every(Nil))) == ("1 = 1", Nil))

    /// The pair that names a round, which every reading of the table is
    /// scoped by.
    @Test
    def theScopeBindsTheSeasonAndTheRoundsName(): Unit \ Assert =
        Assert.assertTrue(Sql.toSql(Sql.term(Schema.scope(2025, "le_mans_24h"))) == (
            "season = ? AND round = ?",
            Value.Integer(2025) :: Value.Text("le_mans_24h") :: Nil
        ))

}
