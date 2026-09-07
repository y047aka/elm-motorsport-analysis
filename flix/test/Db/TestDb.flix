mod Db.TestDb {

    use Db.Laps
    use Db.Statement
    use Db.Value
    use Db.LapRow
    use Db.TestLapRow

    def roundId(): Int32 = 7

    def sampleRows(): List[LapRow.LapRow] =
        LapRow.fromRawLaps(roundId(), TestLapRow.sampleLap() :: TestLapRow.sampleLap() :: Nil)

    @Test
    def creatingDropsTheTableFirst(): Unit \ Assert =
        let (_, statements) = Db.runRecording(() -> Db.runWithError(Laps.create));
        match statements {
            case Statement.Execute(first) :: Statement.Execute(second) :: Nil =>
                Assert.assertTrue(String.startsWith({prefix = "DROP TABLE"}, first));
                Assert.assertTrue(String.startsWith({prefix = "CREATE TABLE laps"}, second))
            case _ => Assert.assertTrue(false)
        }

    @Test
    def theRowsReachTheBoundary(): Unit \ Assert =
        let (result, statements) = Db.runRecording(() -> Db.runWithError(() -> Laps.insertRows(sampleRows())));
        Assert.assertTrue(result == Ok(2));
        match statements {
            case Statement.InsertMany(sql, rows) :: Nil =>
                Assert.assertTrue(String.startsWith({prefix = "INSERT INTO laps"}, sql));
                Assert.assertTrue(List.length(rows) == 2);
                Assert.assertTrue(
                    List.forAll(row -> List.head(row) == Some(Value.Integer(roundId())), rows)
                )
            case _ => Assert.assertTrue(false)
        }

    /// Nothing was written, so a read cannot be answered. The handler says so
    /// rather than handing back an empty round, which would read as a round
    /// with no violations and no cars in it.
    @Test
    def recordingCannotAnswerARead(): Unit \ Assert =
        let (result, statements) = Db.runRecording(() -> SqlRead.fetch("SELECT 1 WHERE ? = ?", Value.Integer(1) :: Value.Integer(1) :: Nil));
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
        let (_, statements) = Db.runRecording(() -> Db.runWithError(() -> {
            Laps.create();
            Laps.insertRows(sampleRows())
        }));
        match statements {
            case Statement.Execute(_) :: Statement.Execute(_) :: Statement.InsertMany(_, _) :: Nil =>
                Assert.assertTrue(true)
            case _ => Assert.assertTrue(false)
        }

    /// What the statements before it are kept by.
    @Test
    def aTransactionThatAnsweredCommitsAfterWhatItSent(): Unit \ Assert =
        let (result, statements) = Db.runRecording(() ->
            Db.runWithError(() -> Db.transact(() -> Laps.insertRows(sampleRows()))));
        Assert.assertTrue(result == Ok(2));
        match statements {
            case Statement.InsertMany(_, _) :: Statement.Commit :: Nil => Assert.assertTrue(true)
            case _ => Assert.assertTrue(false)
        }

    /// The error is the one the caller answered with, not the rollback's.
    @Test
    def aTransactionThatFailedRollsBackAndKeepsItsError(): Unit \ Assert =
        let (result, statements) = Db.runRecording(() -> Db.runWithError(() ->
            Db.transact(() -> {
                discard Laps.insertRows(sampleRows());
                (DbErr.fail(Db.Error.Incomplete("the round was not what it should have been")): Int32)
            })));
        Assert.assertTrue(result == Err(Db.Error.Incomplete("the round was not what it should have been")));
        match statements {
            case Statement.InsertMany(_, _) :: Statement.Rollback :: Nil => Assert.assertTrue(true)
            case _ => Assert.assertTrue(false)
        }


}
