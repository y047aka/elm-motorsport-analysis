pub mod Db.TestDb {
    use Sqlitefx.DbError
    use Sqlitefx.DbTest
    use Sqlitefx.RawSql
    use Sqlitefx.Row.Statement
    use Sqlitefx.SqlValue

    use Db.Laps
    use Db.LapRow
    use Db.TestLapRow

    def roundId(): Int32 = 7

    def sampleRows(): List[LapRow.LapRow] =
        LapRow.fromRawLaps(roundId(), TestLapRow.sampleLap() :: TestLapRow.sampleLap() :: Nil)

    /// What the statements a load sends would be, with no database behind them: each write answers that it took `affected` rows.
    def recorded(affected: Int32, f: Unit -> a \ ef): (Result[DbError.DbErrorKind, a], List[Statement]) \ ef - {Sqlitefx.Db, Sqlitefx.SqlSavepoint, RawSql} =
        RawSql.runWithAllow(() -> DbTest.runRecording(Nil, affected, () -> DbError.runWithKind(f)))

    @Test
    def creatingDropsTheTableFirst(): Unit \ Assert =
        let (_, statements) = recorded(0, Laps.create);
        match statements |> List.map(s -> s#sql) {
            case first :: second :: Nil =>
                Assert.assertTrue(String.startsWith({prefix = "DROP TABLE"}, first));
                Assert.assertTrue(String.startsWith({prefix = "CREATE TABLE laps"}, second))
            case _ => Assert.assertTrue(false)
        }

    /// The rows go out as one statement while they fit in one, a group of values per row in the order the rows were given.
    @Test
    def theRowsReachTheBoundary(): Unit \ Assert =
        let (result, statements) = recorded(2, () -> Laps.insertRows(sampleRows()));
        Assert.assertTrue(result == Ok(2));
        match statements {
            case only :: Nil =>
                let width = List.length(Laps.all());
                Assert.assertTrue(String.startsWith({prefix = "INSERT INTO laps"}, only#sql));
                Assert.assertTrue(List.length(only#params) == 2 * width);
                Assert.assertTrue(List.head(only#params) == Some(SqlValue.Int32(roundId())));
                Assert.assertTrue(List.head(List.drop(width, only#params)) == Some(SqlValue.Int32(roundId())))
            case _ => Assert.assertTrue(false)
        }

    /// A thousand rows to a statement: the thousand and first starts the next one.
    @Test
    def aThousandRowsAreOneStatement(): Unit \ Assert =
        let rows = List.range(0, 1001) |> List.flatMap(_ -> sampleRows()) |> List.take(1001);
        let (result, statements) = recorded(1, () -> Laps.insertRows(rows));
        Assert.assertTrue(result == Ok(2));
        Assert.assertTrue(statements |> List.map(s -> List.length(s#params) / List.length(Laps.all())) == 1000 :: 1 :: Nil)

    @Test
    def anInsertOfNoRowsSendsNothing(): Unit \ Assert =
        let (result, statements) = recorded(0, () -> Laps.insertRows(Nil));
        Assert.assertTrue(result == Ok(0));
        Assert.assertTrue(List.isEmpty(statements))

    @Test
    def theStatementsAreKeptInTheOrderTheyWereSent(): Unit \ Assert =
        let (_, statements) = recorded(2, () -> {
            Laps.create();
            Laps.insertRows(sampleRows())
        });
        match statements |> List.map(s -> s#sql) {
            case drop :: create :: insert :: Nil =>
                Assert.assertTrue(String.startsWith({prefix = "DROP TABLE"}, drop));
                Assert.assertTrue(String.startsWith({prefix = "CREATE TABLE"}, create));
                Assert.assertTrue(String.startsWith({prefix = "INSERT INTO"}, insert))
            case _ => Assert.assertTrue(false)
        }

}
