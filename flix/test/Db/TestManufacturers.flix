mod Db.TestManufacturers {

    use Db.Manufacturers
    use Db.Numbering
    use Db.Teams
    use Db.Value

    /// A name the feed spells one way is its own manufacturer, and a spelling
    /// of another is numbered after the name it answers to -- so the row it
    /// points at is there whether a file has written that name yet or not.
    @Test
    def aSpellingIsNumberedAfterTheNameItAnswersTo(): Unit \ Assert =
        let (_, rows) = Manufacturers.add(Numbering.none(), "Mercedes-AMG" :: "Toyota" :: Nil);
        Assert.assertTrue(
            rows |> List.map(r -> (r#manufacturerId, r#name, r#canonicalId))
                == (1, "Mercedes", 1) :: (2, "Mercedes-AMG", 1) :: (3, "Toyota", 3) :: Nil
        )

    /// The rows are what the run adds, so a name a round already wrote is not
    /// written again by the next.
    @Test
    def aNameIsNumberedOnceHoweverManyRoundsSpellIt(): Unit \ Assert =
        let (first, _) = Manufacturers.add(Numbering.none(), "Mercedes" :: Nil);
        let (second, added) = Manufacturers.add(first, "Mercedes-AMG" :: "Mercedes" :: Nil);
        Assert.assertTrue(
            added |> List.map(r -> (r#manufacturerId, r#name, r#canonicalId))
                == (2, "Mercedes-AMG", 1) :: Nil
        );
        Assert.assertTrue(Manufacturers.idIn(second, "Mercedes") == Some(1))

    @Test
    def aTeamIsNumberedOnceHoweverManyRoundsNameIt(): Unit \ Assert =
        let (first, added) = Teams.add(Numbering.none(), "Hertz Team JOTA" :: "AF Corse" :: Nil);
        Assert.assertTrue(added |> List.map(r -> (r#teamId, r#name))
            == (1, "Hertz Team JOTA") :: (2, "AF Corse") :: Nil);
        let (second, again) = Teams.add(first, "AF Corse" :: Nil);
        Assert.assertTrue(List.isEmpty(again));
        Assert.assertTrue(Teams.idIn(second, "AF Corse") == Some(2))

    // ------------------------------------------------------------ the schema

    /// See `Db.TestLapRow`: `all` and `selection` are two orderings of the one
    /// declaration, and no compiler sees them together.
    @Test
    def theReadingsNameTheColumnsTheLoadBound(): Unit \ Assert =
        Assert.assertTrue(
            Sql.toSql(Sql.clause(Manufacturers.selection()))
                == ("SELECT " + List.join(", ", Manufacturers.columnNames()), Nil)
        );
        Assert.assertTrue(
            Sql.toSql(Sql.clause(Teams.selection()))
                == ("SELECT " + List.join(", ", Teams.columnNames()), Nil)
        )

    @Test
    def theKeysNameColumnsTheTablesDeclare(): Unit \ Assert =
        let manufacturers = Manufacturers.createTable();
        Assert.assertTrue(String.contains({substr = "PRIMARY KEY (manufacturer_id)"}, manufacturers));
        Assert.assertTrue(String.contains({substr = "UNIQUE (name)"}, manufacturers));
        let teams = Teams.createTable();
        Assert.assertTrue(String.contains({substr = "PRIMARY KEY (team_id)"}, teams));
        Assert.assertTrue(String.contains({substr = "UNIQUE (name)"}, teams))

    @Test
    def theRowIsBoundInTheOrderTheColumnsAreNamed(): Unit \ Assert =
        Assert.assertTrue(
            Manufacturers.values({ manufacturerId = 2, name = "Mercedes-AMG", canonicalId = 1 })
                == Value.Integer(2) :: Value.Text("Mercedes-AMG") :: Value.Integer(1) :: Nil
        );
        Assert.assertTrue(
            Teams.values({ teamId = 3, name = "AF Corse" })
                == Value.Integer(3) :: Value.Text("AF Corse") :: Nil
        )

}
