mod Sql.TestExpr {

    use Db.Cars
    use Db.Laps
    use Db.Schema
    use Db.Value
    use Motorsport.Calendar.Entry

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
            Sql.eq(Schema.expr(Laps.columns()#roundId), Sql.i32(4)) ::
            Sql.ne(Schema.expr(Laps.columns()#lapTimeMs), Sql.i32(0)) ::
            Sql.isNotNull(Schema.expr(Laps.columns()#s1Ms)) :: Nil
        );
        Assert.assertTrue(Sql.toSql(Sql.term(expr)) == (
            "round_id = ? AND lap_time_ms <> ? AND s1_ms IS NOT NULL",
            Value.Integer(4) :: Value.Integer(0) :: Nil
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

    def leMans(): Entry = { season = 2025, id = "le_mans_24h", date = "2025-06-14" }

    /// The id `rounds` gave the round, which every reading of either table is
    /// scoped by. Both tables have a `round_id`, so the scope names the source
    /// it means: bare, it would bind to whichever side of a join happened to
    /// carry one.
    ///
    /// The id is read back rather than computed, so what the scope binds is
    /// still the pair the calendar names the round by, and a database whose
    /// `rounds` does not have it scopes to no rows.
    @Test
    def theRowsAreScopedToTheRoundIdOfTheTableTheyAreOf(): Unit \ Assert =
        let scope = source ->
            "${source}.round_id = (SELECT round_id FROM rounds"
                + " WHERE season = ? AND round_key = ?)";
        let named = Value.Integer(2025) :: Value.Text("le_mans_24h") :: Nil;
        let lapNumbers = Laps.rows(leMans()) |> Sql.map(c -> c#lapNumber) |> Sql.toStatement;
        Assert.assertTrue(Sql.toSql(lapNumbers) == (
            "SELECT lap_number FROM laps WHERE ${scope("laps")}", named
        ));
        let carNumbers = Cars.rows(leMans()) |> Sql.map(c -> c#carNumber) |> Sql.toStatement;
        Assert.assertTrue(Sql.toSql(carNumbers) == (
            "SELECT car_number FROM cars WHERE ${scope("cars")}", named
        ))

    /// A query reading the round's rows from inside a common table expression
    /// of its own has a source that is text, so it takes the predicate.
    @Test
    def theScopeIsAlsoHadAsAPredicate(): Unit \ Assert =
        Assert.assertTrue(Sql.toSql(Sql.term(Laps.inRound(leMans()))) == (
            "laps.round_id = (SELECT round_id FROM rounds WHERE season = ? AND round_key = ?)",
            Value.Integer(2025) :: Value.Text("le_mans_24h") :: Nil
        ))

    /// A source that renames the table names itself, which is what a join's
    /// side is.
    @Test
    def aScopeOfARenamedSourceNamesTheRename(): Unit \ Assert =
        let c = Cars.columns();
        Assert.assertTrue(
            Sql.toSql(Sql.term(Db.Rounds.scope(Schema.qualified("c", c#roundId), leMans())))
                == ("c.round_id = (SELECT round_id FROM rounds"
                        + " WHERE season = ? AND round_key = ?)",
                    Value.Integer(2025) :: Value.Text("le_mans_24h") :: Nil)
        )

}
