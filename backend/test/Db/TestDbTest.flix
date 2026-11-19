pub mod Db.TestDbTest {
    use Lite3fx.DbError
    use Lite3fx.DbError.DbErrorKind
    use Lite3fx.DbTest
    use Lite3fx.Recording.Statement
    use Lite3fx.SqlValue

    /// The query the handlers below answer: what one round's lap times are, in
    /// the order they were run.
    def lapTimes(roundId: Int32): Sql.Query[String] =
        Sql.rows(Sql.raw("laps"))
            |> Sql.filter(_ -> Sql.written(Sql.frag("round_id = ?", SqlValue.Int32(roundId) :: Nil)))
            |> Sql.orderBy(Sql.raw("lap_number") :: Nil)
            |> Sql.map(_ -> Sql.text("lap_time"))

    def driverNames(): Sql.Query[String] =
        Sql.rows(Sql.raw("entries"))
            |> Sql.map(_ -> Sql.text("driver_name"))

    /// A query and the reading of what it comes back as, driven together with no
    /// database: the SQL it sent, the rows it was given, and the value the
    /// reading made of them.
    @Test
    def aQueryAndItsReadingAreAnsweredWithTheRowsItIsGiven(): Unit \ Assert =
        let rows = TestCells.row(Some("1:35.365") :: Nil)
            :: TestCells.row(Some("1:36.101") :: Nil)
            :: Nil;
        Assert.assertTrue(
            DbTest.runWithRows(rows, () -> DbError.runWithKind(() -> Sql.selectAll(lapTimes(7))))
                == Ok("1:35.365" :: "1:36.101" :: Nil)
        )

    /// The rows a `SELECT` is answered with are chosen by its own text, so two
    /// queries are answered apart.
    @Test
    def eachStatementIsAnsweredByItsOwnText(): Unit \ Assert =
        let rowsFor = sql ->
            if (String.startsWith({prefix = "SELECT driver_name"}, sql))
                Some(TestCells.row(Some("Will STEVENS") :: Nil) :: Nil)
            else
                Some(TestCells.row(Some("7") :: Nil) :: Nil);
        let (drivers, times) = DbTest.runWithTable(rowsFor, () ->
            (DbError.runWithKind(() -> Sql.selectAll(driverNames())),
             DbError.runWithKind(() -> Sql.selectAll(lapTimes(7)))));
        Assert.assertTrue(drivers == Ok("Will STEVENS" :: Nil));
        Assert.assertTrue(times == Ok("7" :: Nil))

    /// A `SELECT` no answer is named for comes back with no rows, which a
    /// reading of one answers as the failure that it is.
    @Test
    def aQueryWithNoAnswerNamedForItHasNoRows(): Unit \ Assert =
        let outcome = DbTest.runWithTable(_ -> None, () ->
            DbError.runWithKind(() -> Sql.selectOne("the round", lapTimes(7))));
        Assert.assertTrue(outcome == Err(DbErrorKind.NoRow("the round")))

    /// A write that is refused reaches the caller that asked for it, rather than
    /// the handler that stood in for the database.
    @Test
    def aWriteThatIsRefusedReachesTheCaller(): Unit \ Assert =
        let refused = DbErrorKind.Other("UNIQUE constraint failed: laps.round_id");
        let outcome = DbTest.runFailingWrite(refused, () ->
            DbError.runWithKind(() -> discard Lite3fx.Sql.execute("INSERT INTO laps VALUES (1)", Nil)));
        Assert.assertTrue(outcome == Err(refused))

    /// The two are separate effects, so a handler answering reads goes around one
    /// refusing writes: a caller that reads back what it failed to write is the
    /// case a test of this has to be able to draw.
    @Test
    def aReadIsAnsweredWhereTheWriteWasRefused(): Unit \ Assert =
        let outcome = DbTest.runWithRows(TestCells.row(Some("1:35.365") :: Nil) :: Nil, () ->
            DbTest.runFailingWrite(DbError.busy("database is locked"), () -> (
                DbError.runWithKind(() -> discard Lite3fx.Sql.execute("INSERT INTO laps VALUES (1)", Nil)),
                DbError.runWithKind(() -> Sql.selectAll(lapTimes(7)))
            )));
        Assert.assertTrue(outcome == (Err(DbError.busy("database is locked")), Ok("1:35.365" :: Nil)))

    /// A write and the reading of what came back after it, under one test: the
    /// statements kept and the `SELECT` answered, which is what a caller reading
    /// the round it just wrote needs.
    @Test
    def aWriteAndTheReadAfterItAreDrivenTogether(): Unit \ Assert =
        let rows = TestCells.row(Some("1:35.365") :: Nil) :: Nil;
        let ((written, readBack), sent) = DbTest.runRecording(rows, 1, () -> (
            DbError.runWithKind(() -> discard Lite3fx.Sql.execute("UPDATE laps SET lap_time = '1:35.365'", Nil)),
            DbError.runWithKind(() -> Sql.selectAll(lapTimes(7)))));
        Assert.assertTrue(written == Ok(()));
        Assert.assertTrue(readBack == Ok("1:35.365" :: Nil));
        Assert.assertTrue(match sent {
            case Statement.Execute(sql, Nil) :: Statement.Fetch(_, _) :: Nil =>
                sql == "UPDATE laps SET lap_time = '1:35.365'"
            case _ => false
        })

    /// A write answers with the rows the database took, which is the count a
    /// run reports beside what it decoded.
    @Test
    def aWriteAnswersWithTheRowsTheDatabaseTook(): Unit \ Assert =
        let (taken, _) = DbTest.runRecording(Nil, 3, () ->
            DbError.runWithKind(() -> Lite3fx.Sql.execute("UPDATE laps SET deleted = 1", Nil)));
        Assert.assertTrue(taken == Ok(3))

    /// Several `SELECT`s are answered apart while every statement is kept.
    @Test
    def eachQueryIsAnsweredByItsOwnTextWhileAllAreKept(): Unit \ Assert =
        let rowsFor = sql ->
            if (String.startsWith({prefix = "SELECT driver_name"}, sql))
                Some(TestCells.row(Some("Will STEVENS") :: Nil) :: Nil)
            else
                Some(TestCells.row(Some("1:35.365") :: Nil) :: Nil);
        let (both, sent) = DbTest.runRecordingWith(rowsFor, 0, () -> (
            DbError.runWithKind(() -> Sql.selectAll(driverNames())),
            DbError.runWithKind(() -> Sql.selectAll(lapTimes(7)))));
        Assert.assertTrue(
            both == (Ok("Will STEVENS" :: Nil), Ok("1:35.365" :: Nil))
                and List.length(sent) == 2
        )

}
