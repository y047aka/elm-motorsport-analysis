mod Db.TestRounds {

    use Db.Rounds
    use Db.Value
    use Motorsport.Calendar
    use Motorsport.Calendar.Entry

    def fuji(): Entry = { season = 2025, id = "fuji_6h", date = "2025-09-28" }
    def spa2026(): Entry = { season = 2026, id = "spa_6h", date = "2026-05-09" }

    /// `spa_6h` ran in 2025 and in 2026, so the season is half of what names a
    /// round and half of what the id is looked up by.
    @Test
    def theEntriesAreNumberedFromOneInTheOrderGiven(): Unit \ Assert =
        let rows = Rounds.rowsFor(fuji() :: spa2026() :: Nil);
        Assert.assertTrue(List.map(r -> r#roundId, rows) == 1 :: 2 :: Nil);
        Assert.assertTrue(List.map(r -> (r#season, r#roundKey), rows)
            == (2025, "fuji_6h") :: (2026, "spa_6h") :: Nil)

    @Test
    def anIdIsLookedUpByTheSeasonAndTheRoundsName(): Unit \ Assert =
        let rows = Rounds.rowsFor(fuji() :: spa2026() :: Nil);
        Assert.assertTrue(Rounds.idIn(rows, spa2026()) == Some(2));
        Assert.assertTrue(
            Rounds.idIn(rows, { season = 2025, id = "spa_6h", date = "2025-05-10" }) == None
        )

    /// Every round the run may load takes a row, so a task can always be
    /// numbered.
    @Test
    def theCalendarNumbersEveryRoundItLists(): Unit \ Assert =
        let rows = Rounds.rowsFor(Calendar.entries());
        Assert.assertTrue(List.length(rows) == List.length(Calendar.entries()));
        Assert.assertTrue(
            Calendar.entries() |> List.forAll(entry -> Rounds.idIn(rows, entry) != None)
        )

    @Test
    def theRowIsBoundInTheOrderTheColumnsAreNamed(): Unit \ Assert =
        match Rounds.rowsFor(fuji() :: Nil) {
            case row :: _ =>
                Assert.assertTrue(Rounds.values(row)
                    == Value.Integer(1) :: Value.Integer(2025) ::
                       Value.Text("fuji_6h") :: Value.Text("2025-09-28") :: Nil)
            case Nil => Assert.assertTrue(false)
        }

    /// See `Db.TestLapRow`: `all` and `selection` are two orderings of the one
    /// declaration, and no compiler sees them together.
    @Test
    def theReadingNamesTheColumnsTheLoadBound(): Unit \ Assert =
        Assert.assertTrue(
            Sql.toSql(Sql.clause(Rounds.selection()))
                == ("SELECT " + List.join(", ", Rounds.columnNames()), Nil)
        )

    /// The id is the key the other two tables carry; the pair is the one every
    /// reader has, and is what `idOf` looks the id up by.
    @Test
    def theKeysNameColumnsTheTableDeclares(): Unit \ Assert =
        let declared = Rounds.columnNames();
        let named = List.append(Rounds.primaryKey(), Rounds.namedKey())
            |> List.map(c -> c#name);
        Assert.assertTrue(named |> List.forAll(name -> List.memberOf(name, declared)));
        let ddl = Rounds.createTable();
        Assert.assertTrue(String.contains({substr = "PRIMARY KEY (round_id)"}, ddl));
        Assert.assertTrue(String.contains({substr = "UNIQUE (season, round_key)"}, ddl))

    /// An integer primary key is SQLite's own tree already, so this table is
    /// the one that keeps it.
    @Test
    def theRowsStayInSqlitesOwnTree(): Unit \ Assert =
        Assert.assertTrue(not String.contains({substr = "WITHOUT ROWID"}, Rounds.createTable()))

}
