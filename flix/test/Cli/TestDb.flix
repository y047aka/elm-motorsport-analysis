mod Cli.TestDb {

    use Cli.Db
    use Cli.Db.Statement
    use Cli.Db.LapRow
    use Cli.Db.TestLapRow

    def sampleRows(): List[LapRow.LapRow] =
        LapRow.fromRawLaps(
            { season = 2025, id = "fuji_6h", date = "2025-09-28" },
            TestLapRow.sampleLap() :: TestLapRow.sampleLap() :: Nil
        )

    @Test
    def prepareDropsTheTableBeforeCreatingIt(): Unit \ Assert =
        let (result, statements) = Db.runRecording(() -> Db.prepare());
        Assert.assertTrue(result == Ok());
        match statements {
            case Statement.Execute(first) :: Statement.Execute(second) :: Nil =>
                Assert.assertTrue(String.startsWith({prefix = "DROP TABLE"}, first));
                Assert.assertTrue(String.startsWith({prefix = "CREATE TABLE laps"}, second))
            case _ => Assert.assertTrue(false)
        }

    @Test
    def theRowsReachTheBoundary(): Unit \ Assert =
        let (result, statements) = Db.runRecording(() -> Db.insertLaps(sampleRows()));
        Assert.assertTrue(result == Ok(2));
        match statements {
            case Statement.InsertLaps(rows) :: Nil =>
                Assert.assertTrue(List.length(rows) == 2);
                Assert.assertTrue(List.forAll(row -> row#round == "fuji_6h", rows))
            case _ => Assert.assertTrue(false)
        }

    @Test
    def theStatementsAreKeptInTheOrderTheyWereSent(): Unit \ Assert =
        let (_, statements) = Db.runRecording(() -> {
            discard Db.prepare();
            Db.insertLaps(sampleRows())
        });
        match statements {
            case Statement.Execute(_) :: Statement.Execute(_) :: Statement.InsertLaps(_) :: Nil =>
                Assert.assertTrue(true)
            case _ => Assert.assertTrue(false)
        }


}
