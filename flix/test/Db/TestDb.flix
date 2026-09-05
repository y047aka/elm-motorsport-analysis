mod Db.TestDb {

    use Db.Laps
    use Db.Statement
    use Db.Value
    use Db.LapRow
    use Db.TestLapRow

    def sampleRows(): List[LapRow.LapRow] =
        LapRow.fromRawLaps(
            { season = 2025, id = "fuji_6h", date = "2025-09-28" },
            TestLapRow.sampleLap() :: TestLapRow.sampleLap() :: Nil
        )

    @Test
    def creatingDropsTheTableFirst(): Unit \ Assert =
        let (result, statements) = Db.runRecording(() -> Laps.create());
        Assert.assertTrue(result == Ok());
        match statements {
            case Statement.Execute(first) :: Statement.Execute(second) :: Nil =>
                Assert.assertTrue(String.startsWith({prefix = "DROP TABLE"}, first));
                Assert.assertTrue(String.startsWith({prefix = "CREATE TABLE laps"}, second))
            case _ => Assert.assertTrue(false)
        }

    @Test
    def theRowsReachTheBoundary(): Unit \ Assert =
        let (result, statements) = Db.runRecording(() -> Laps.insertRows(sampleRows()));
        Assert.assertTrue(result == Ok(2));
        match statements {
            case Statement.InsertMany(sql, rows) :: Nil =>
                Assert.assertTrue(String.startsWith({prefix = "INSERT INTO laps"}, sql));
                Assert.assertTrue(List.length(rows) == 2);
                Assert.assertTrue(
                    List.forAll(row -> List.memberOf(Value.Text("fuji_6h"), row), rows)
                )
            case _ => Assert.assertTrue(false)
        }

    /// Nothing was written, so a read cannot be answered. The handler says so
    /// rather than handing back an empty round, which would read as a round
    /// with no violations and no cars in it.
    @Test
    def recordingCannotAnswerARead(): Unit \ Assert =
        let (result, statements) = Db.runRecording(() -> Db.fetch("SELECT 1 WHERE ? = ?", Value.Integer(1) :: Value.Integer(1) :: Nil));
        match result {
            case Ok(_)  => Assert.assertTrue(false)
            case Err(_) => Assert.assertTrue(true)
        };
        match statements {
            case Statement.Fetch(sql, params) :: Nil =>
                Assert.assertTrue(sql == "SELECT 1 WHERE ? = ?");
                Assert.assertTrue(params == Value.Integer(1) :: Value.Integer(1) :: Nil)
            case _                           => Assert.assertTrue(false)
        }

    @Test
    def theStatementsAreKeptInTheOrderTheyWereSent(): Unit \ Assert =
        let (_, statements) = Db.runRecording(() -> {
            discard Laps.create();
            Laps.insertRows(sampleRows())
        });
        match statements {
            case Statement.Execute(_) :: Statement.Execute(_) :: Statement.InsertMany(_, _) :: Nil =>
                Assert.assertTrue(true)
            case _ => Assert.assertTrue(false)
        }


}
