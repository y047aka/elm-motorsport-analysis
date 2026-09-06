mod Sql.TestExpr {

    use Db.Cars
    use Db.Laps
    use Db.Schema
    use Db.Value

    @Test
    def aComparisonBindsTheValueItComparesAgainst(): Unit \ Assert =
        let expr = Sql.eq(Schema.expr(Laps.columns()#lapNumber), Sql.i32(1));
        Assert.assertTrue(
            Sql.toSql(Sql.term(expr)) == ("lap_number = ?", Value.Integer(1) :: Nil)
        )

    /// `IS NULL` reads nothing, so it binds nothing.
    @Test
    def aNullTestNamesTheColumnAlone(): Unit \ Assert =
        let expr = Sql.isNotNull(Schema.expr(Laps.columns()#miniSectorTimeMs));
        Assert.assertTrue(
            Sql.toSql(Sql.term(expr)) == ("mini_sector_time_ms IS NOT NULL", Nil)
        )

    @Test
    def predicatesAreAndedInTheOrderGiven(): Unit \ Assert =
        let expr = Sql.every(
            Sql.eq(Schema.expr(Laps.columns()#season), Sql.i32(2025)) ::
            Sql.ne(Schema.expr(Laps.columns()#lapTimeMs), Sql.i32(0)) ::
            Sql.isNotNull(Schema.expr(Laps.columns()#s1Ms)) :: Nil
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
        let lap1 = Schema.qualified("l1", Laps.columns()#carNumber);
        Assert.assertTrue(Schema.name(lap1) == "l1.car_number");
        Assert.assertTrue(
            Sql.toSql(Sql.term(Sql.eq(Schema.expr(lap1), Sql.str("12"))))
                == ("l1.car_number = ?", Value.Text("12") :: Nil)
        );
        Assert.assertTrue(
            Sql.toSql(Sql.clause(Schema.read(lap1))) == ("SELECT l1.car_number", Nil)
        );
        Assert.assertTrue(Sql.decode(Schema.read(lap1), Some("12") :: Nil) == Ok("12"))

    /// The pair that names a round, which every reading of either table is
    /// scoped by. Both tables have `season` and `round`, so the scope names
    /// the source it means: bare, it would bind to whichever side of a join
    /// happened to carry them.
    @Test
    def theScopeBindsTheSeasonAndTheRoundsNameOfTheTableItIsOf(): Unit \ Assert =
        Assert.assertTrue(Sql.toSql(Sql.term(Laps.scope(2025, "le_mans_24h"))) == (
            "laps.season = ? AND laps.round = ?",
            Value.Integer(2025) :: Value.Text("le_mans_24h") :: Nil
        ));
        Assert.assertTrue(Sql.toSql(Sql.term(Cars.scope(2025, "le_mans_24h"))) == (
            "cars.season = ? AND cars.round = ?",
            Value.Integer(2025) :: Value.Text("le_mans_24h") :: Nil
        ))

    /// A source that renames the table names itself, which is what a join's
    /// side is.
    @Test
    def aScopeOfARenamedSourceNamesTheRename(): Unit \ Assert =
        let c = Cars.columns();
        Assert.assertTrue(
            Sql.toSql(Sql.term(Schema.scopeOf("c", c#season, c#round, 2025, "le_mans_24h")))
                == ("c.season = ? AND c.round = ?",
                    Value.Integer(2025) :: Value.Text("le_mans_24h") :: Nil)
        )

}
