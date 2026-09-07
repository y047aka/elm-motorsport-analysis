mod Sql.TestStatement {

    use Db.Value
    use Sql.Key

    /// A column of a table that is not this application's: what the builders
    /// read of one is its name, the type it takes, and what it binds.
    type alias Row = {round = String, lapNumber = Int32}

    type alias Col = {name = String, sqlType = String, bind = Row -> Value}

    def round_(): Col =
        { name = "round", sqlType = "text not null", bind = r -> Value.Text(r#round) }

    def lapNumber(): Col =
        { name = "lap_number", sqlType = "int not null", bind = r -> Value.Integer(r#lapNumber) }

    def columns(): List[Col] =
        round_() :: lapNumber() :: Nil

    @Test
    def aTableDeclaresItsColumnsAndThenItsKeys(): Unit \ Assert =
        Assert.assertTrue(
            Sql.createTable("laps", columns(), Key.Primary(round_() :: lapNumber() :: Nil) :: Nil,
                    Sql.Storage.Rowid)
                == String.unlines(
                    "CREATE TABLE laps (" ::
                    "  round text not null," ::
                    "  lap_number int not null," ::
                    "  PRIMARY KEY (round, lap_number)" :: Nil
                ) + ")"
        )

    /// The rows in the primary key's own tree rather than in one of SQLite's.
    @Test
    def aTableMaySayWhereItsRowsLive(): Unit \ Assert =
        Assert.assertTrue(
            String.endsWith(
                {suffix = "  PRIMARY KEY (round)\n) WITHOUT ROWID"},
                Sql.createTable("laps", columns(), Key.Primary(round_() :: Nil) :: Nil,
                    Sql.Storage.WithoutRowid)
            )
        )

    @Test
    def aTableTakesAsManyKeysAsItDeclares(): Unit \ Assert =
        let ddl = Sql.createTable("laps", columns(),
            Key.Primary(round_() :: Nil) :: Key.Unique(lapNumber() :: Nil) :: Nil,
            Sql.Storage.Rowid);
        Assert.assertTrue(String.contains({substr = "  PRIMARY KEY (round),\n  UNIQUE (lap_number)\n)"}, ddl))

    @Test
    def droppingATableThatIsNotThereIsNotAnError(): Unit \ Assert =
        Assert.assertTrue(Sql.dropTableIfExists("laps") == "DROP TABLE IF EXISTS laps")

    /// The statement names the columns and the rows are bound in that order,
    /// both read off the one list.
    @Test
    def anInsertBindsEachRowInTheOrderItNamesTheColumns(): Unit \ Assert =
        let (statement, bound) = Sql.insertRows("laps", columns(),
            { round = "le_mans_24h", lapNumber = 1 } :: { round = "fuji_6h", lapNumber = 12 } :: Nil);
        Assert.assertTrue(statement == "INSERT INTO laps (round, lap_number) VALUES (?, ?)");
        Assert.assertTrue(bound == (
            (Value.Text("le_mans_24h") :: Value.Integer(1) :: Nil) ::
            (Value.Text("fuji_6h") :: Value.Integer(12) :: Nil) :: Nil
        ))

    @Test
    def anInsertOfNoRowsIsStillTheStatement(): Unit \ Assert =
        let (statement, bound) = Sql.insertRows("laps", columns(), (Nil: List[Row]));
        Assert.assertTrue(statement == "INSERT INTO laps (round, lap_number) VALUES (?, ?)");
        Assert.assertTrue(bound == Nil)

}
