pub mod Db.TestDb {
    use Lite3fx.DbErr
    use Lite3fx.DbError
    use Lite3fx.DbError.DbErrorKind
    use Lite3fx.DbError.Failure
    use Lite3fx.DbTest
    use Lite3fx.Recording
    use Lite3fx.Recording.Statement
    use Lite3fx.SqlRead
    use Lite3fx.SqlValue
    use Lite3fx.SqlWrite
    use Lite3fx.Tx

    use Db.Laps
    use Db.LapRow
    use Db.TestLapRow

    def roundId(): Int32 = 7

    def sampleRows(): List[LapRow.LapRow] =
        LapRow.fromRawLaps(roundId(), TestLapRow.sampleLap() :: TestLapRow.sampleLap() :: Nil)

    @Test
    def creatingDropsTheTableFirst(): Unit \ Assert =
        let (_, statements) = Recording.statements(() -> DbError.runWithKind(Laps.create));
        match statements {
            case Statement.Execute(first, _) :: Statement.Execute(second, _) :: Nil =>
                Assert.assertTrue(String.startsWith({prefix = "DROP TABLE"}, first));
                Assert.assertTrue(String.startsWith({prefix = "CREATE TABLE laps"}, second))
            case _ => Assert.assertTrue(false)
        }

    /// The savepoint is SQLite's, so it goes out as a statement like any
    /// other -- which is what lets a handler standing in for a database see it.
    ///
    /// The handler never fails the statements it is asked to mark, so the
    /// failure effects a savepoint can raise are discharged here.
    def marked(name: String, f: Unit -> Unit \ ef): List[String] \ (ef - Lite3fx.Db) + Assert =
        let (outcome, statements) = Recording.statements(() ->
            DbError.runWithKind(() -> Tx.withSavepoint(name, f)));
        Assert.assertTrue(outcome == Ok(Ok(())));
        statements |> List.map(s -> match s { case Statement.Execute(sql, _) => sql case _ => "" })

    @Test
    def aSavepointIsMarkedAndReleasedAroundWhatItHolds(): Unit \ Assert =
        Assert.assertTrue(
            marked("round", () -> discard Lite3fx.Sql.execute("SELECT 1", Nil))
                == "SAVEPOINT round" :: "SELECT 1" :: "RELEASE SAVEPOINT round" :: Nil
        )

    /// A failure inside is taken back to the mark, and the mark is released
    /// either way so the caller is not left standing in one.
    @Test
    def aFailureInsideIsTakenBackToTheMark(): Unit \ Assert =
        let refused = DbErrorKind.Other("the round was not what it should have been");
        let (result, statements) = Recording.statements(() ->
            DbError.runWithKind(() -> Tx.withSavepoint("round", () -> {
                DbErr.raise(refused);
                ()
            })));
        let expected: Result[DbErrorKind, Result[Failure, Unit]] = Ok(Err(DbError.toFailure(refused)));
        Assert.assertTrue(result == expected);
        Assert.assertTrue(
            statements |> List.map(s -> match s { case Statement.Execute(sql, _) => sql case _ => "" })
                == "SAVEPOINT round" :: "ROLLBACK TO SAVEPOINT round" :: "RELEASE SAVEPOINT round" :: Nil
        )

    /// A name is the one value that reaches the statement's text, so a name
    /// that is not a name is refused before any statement is sent.
    @Test
    def aNameThatIsNotANameSendsNoStatement(): Unit \ Assert =
        let (outcome, statements) = Recording.statements(() -> DbError.runWithKind(() ->
            Tx.withSavepoint("round; DROP TABLE laps", () -> discard Lite3fx.Sql.execute("SELECT 1", Nil))));
        Assert.assertTrue(outcome == Ok(Err(Failure.Permanent(DbErrorKind.Other(
            "not a savepoint name: round; DROP TABLE laps (expected ^[a-z_][a-z0-9_]*$)")))));
        Assert.assertTrue(statements == Nil)

    @Test
    def theRowsReachTheBoundary(): Unit \ Assert =
        let (result, statements) = Recording.statements(() -> DbError.runWithKind(() -> Laps.insertRows(sampleRows())));
        Assert.assertTrue(result == Ok(2));
        match statements {
            case Statement.InsertMany(sql, rows) :: Nil =>
                Assert.assertTrue(String.startsWith({prefix = "INSERT INTO laps"}, sql));
                Assert.assertTrue(List.length(rows) == 2);
                Assert.assertTrue(
                    List.forAll(row -> List.head(row) == Some(SqlValue.Int32(roundId())), rows)
                )
            case _ => Assert.assertTrue(false)
        }

    /// Nothing was written, so a read cannot be answered. The handler says so
    /// rather than handing back an empty round, which would read as a round
    /// with no violations and no cars in it.
    @Test
    def recordingCannotAnswerARead(): Unit \ Assert =
        let (result, statements) = Recording.statements(() -> SqlRead.fetch("SELECT 1 WHERE ? = ?", SqlValue.Int32(1) :: SqlValue.Int32(1) :: Nil));
        match result {
            case Ok(_)  => Assert.assertTrue(false)
            case Err(_) => Assert.assertTrue(true)
        };
        match statements {
            case Statement.Fetch(sql, params) :: Nil =>
                Assert.assertTrue(sql == "SELECT 1 WHERE ? = ?");
                Assert.assertTrue(params == SqlValue.Int32(1) :: SqlValue.Int32(1) :: Nil)
            case _                           => Assert.assertTrue(false)
        }

    @Test
    def theStatementsAreKeptInTheOrderTheyWereSent(): Unit \ Assert =
        let (_, statements) = Recording.statements(() -> DbError.runWithKind(() -> {
            Laps.create();
            Laps.insertRows(sampleRows())
        }));
        match statements {
            case Statement.Execute(_, _) :: Statement.Execute(_, _) :: Statement.InsertMany(_, _) :: Nil =>
                Assert.assertTrue(true)
            case _ => Assert.assertTrue(false)
        }

    /// What the statements before it are kept by.
    @Test
    def aTransactionThatAnsweredCommitsAfterWhatItSent(): Unit \ Assert =
        let (result, statements) = Recording.statements(() ->
            DbError.runWithKind(() -> Tx.transact(() -> Laps.insertRows(sampleRows()))));
        Assert.assertTrue(result == Ok(2));
        match statements {
            case Statement.InsertMany(_, _) :: Statement.Commit :: Nil => Assert.assertTrue(true)
            case _ => Assert.assertTrue(false)
        }

    /// The error is the one the caller answered with, not the rollback's.
    @Test
    def aTransactionThatFailedRollsBackAndKeepsItsError(): Unit \ Assert =
        let (result, statements) = Recording.statements(() -> DbError.runWithKind(() ->
            Tx.transact(() -> {
                discard Laps.insertRows(sampleRows());
                (DbErr.raise(DbErrorKind.Other("the round was not what it should have been")): Int32)
            })));
        Assert.assertTrue(result == Err(DbErrorKind.Other("the round was not what it should have been")));
        match statements {
            case Statement.InsertMany(_, _) :: Statement.Rollback :: Nil => Assert.assertTrue(true)
            case _ => Assert.assertTrue(false)
        }

    /// A transient failure is a failure: what was sent before it is taken back.
    @Test
    def aTransientFailureRollsTheTransactionBack(): Unit \ Assert =
        let (result, statements) = Recording.statements(() -> DbError.runWithKind(() ->
            Tx.transact(() -> {
                discard Laps.insertRows(sampleRows());
                (DbError.raise(DbError.busy("database is locked")): Int32)
            })));
        Assert.assertTrue(result == Err(DbError.busy("database is locked")));
        match statements {
            case Statement.InsertMany(_, _) :: Statement.Rollback :: Nil => Assert.assertTrue(true)
            case _ => Assert.assertTrue(false)
        }

    /// Which of the two effects a failure travels by is read off its
    /// constructor, so the two that trying again may get past are named here
    /// and nowhere else.
    @Test
    def whichFailingsTryingAgainIsWorthTrying(): Unit \ Assert =
        Assert.assertTrue(DbError.isTransient(DbError.busy("database is locked")));
        Assert.assertTrue(DbError.isTransient(DbError.unreachable("no such file")));
        Assert.assertTrue(not(DbError.isTransient(DbErrorKind.Other("no such table: laps"))));
        Assert.assertTrue(not(DbError.isTransient(DbErrorKind.NoRow("the summary"))))

    /// A rollback that fails says nothing the failure it is undoing does not, so its
    /// answer is discarded: the failure the caller learns is the one that ended the
    /// transaction, not the one that tried to undo it.
    @Test
    def aFailingRollbackDoesNotReplaceTheFailureItUndoes(): Unit \ Assert =
        let outcome = run {
            DbError.runWithKind(() -> Tx.transact(() ->
                DbErr.raise(DbErrorKind.Other("the round's own failure"))))
        } with handler SqlWrite {
            def execute(_sql, _params, k) = k(Ok(0))
            def executeReturning(_sql, _params, k) = k(Ok(Nil))
            def insertMany(_sql, _rows, k) = k(Ok(0))
            def commit(k) = k(Ok())
            def rollback(k) = k(Err(DbErrorKind.Other("the rollback's failure")))
        };
        Assert.assertTrue(match outcome {
            case Err(error) => "${error}" == "the round's own failure"
            case Ok(_)      => false
        })

}
