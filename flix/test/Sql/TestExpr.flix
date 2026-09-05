mod Sql.TestExpr {

    use Db.Laps
    use Db.Value

    @Test
    def aComparisonBindsTheValueItComparesAgainst(): Unit \ Assert =
        let expr = Sql.eq(Laps.expr(Laps.columns()#lapNumber), Sql.i32(1));
        Assert.assertTrue(
            Sql.toSql(Sql.term(expr)) == ("lap_number = ?", Value.Integer(1) :: Nil)
        )

    /// `IS NULL` reads nothing, so it binds nothing.
    @Test
    def aNullTestNamesTheColumnAlone(): Unit \ Assert =
        let expr = Sql.isNotNull(Laps.expr(Laps.columns()#miniSectorTimeMs));
        Assert.assertTrue(
            Sql.toSql(Sql.term(expr)) == ("mini_sector_time_ms IS NOT NULL", Nil)
        )

    @Test
    def predicatesAreAndedInTheOrderGiven(): Unit \ Assert =
        let expr = Sql.every(
            Sql.eq(Laps.expr(Laps.columns()#season), Sql.i32(2025)) ::
            Sql.ne(Laps.expr(Laps.columns()#lapTimeMs), Sql.i32(0)) ::
            Sql.isNotNull(Laps.expr(Laps.columns()#s1Ms)) :: Nil
        );
        Assert.assertTrue(Sql.toSql(Sql.term(expr)) == (
            "season = ? AND lap_time_ms <> ? AND s1_ms IS NOT NULL",
            Value.Integer(2025) :: Value.Integer(0) :: Nil
        ))

    @Test
    def nothingAskedOfTheRowsHoldsOfEveryRow(): Unit \ Assert =
        Assert.assertTrue(Sql.toSql(Sql.term(Sql.every(Nil))) == ("1 = 1", Nil))

    /// A join names its sides' columns by the source they came from, and the
    /// column is the table's either way -- the same reading, under that name.
    @Test
    def aQualifiedColumnIsTheOneTheSourceHas(): Unit \ Assert =
        let lap1 = Laps.qualified("l1", Laps.columns()#carNumber);
        Assert.assertTrue(Laps.name(lap1) == "l1.car_number");
        Assert.assertTrue(
            Sql.toSql(Sql.term(Sql.eq(Laps.expr(lap1), Sql.str("12"))))
                == ("l1.car_number = ?", Value.Text("12") :: Nil)
        );
        Assert.assertTrue(
            Sql.toSql(Sql.clause(Laps.read(lap1))) == ("SELECT l1.car_number", Nil)
        );
        Assert.assertTrue(Sql.decode(Laps.read(lap1), Some("12") :: Nil) == Ok("12"))

    /// The pair that names a round, which every reading of the table is
    /// scoped by.
    @Test
    def theScopeBindsTheSeasonAndTheRoundsName(): Unit \ Assert =
        Assert.assertTrue(Sql.toSql(Sql.term(Laps.scope(2025, "le_mans_24h"))) == (
            "season = ? AND round = ?",
            Value.Integer(2025) :: Value.Text("le_mans_24h") :: Nil
        ))

}
