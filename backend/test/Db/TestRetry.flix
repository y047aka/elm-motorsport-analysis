pub mod Db.TestRetry {
    use Lite3fx.DbErr
    use Lite3fx.DbError
    use Lite3fx.DbError.DbErrorKind
    use Lite3fx.DbError.Failure
    use Lite3fx.DbError.TransientKind
    use Lite3fx.DbTest
    use Lite3fx.Recording
    use Lite3fx.Recording.Statement
    use Lite3fx.Retry

    /// The window a try waits inside doubles per try and stops at the ceiling.
    @Test
    def theWindowDoublesAndStopsAtTheCeiling(): Unit \ Assert = {
        let c = { attempts = 4, base = Util.Duration.fromMillis(1000), cap = Util.Duration.fromMillis(5000) };
        Assert.assertTrue(Retry.backoff(c, 0, 999) == Util.Duration.fromMillis(999));
        Assert.assertTrue(Retry.backoff(c, 1, 999) == Util.Duration.fromMillis(1998));
        Assert.assertTrue(Retry.backoff(c, 2, 999) == Util.Duration.fromMillis(3996));
        Assert.assertTrue(Retry.backoff(c, 3, 999) == Util.Duration.fromMillis(4995));
        Assert.assertTrue(Retry.backoff(c, 9, 999) == Util.Duration.fromMillis(4995))
    }

    /// Full jitter draws from the whole window, so a draw of nothing waits
    /// nothing and a draw past the window is held inside it.
    @Test
    def theDrawIsHeldInsideTheWindow(): Unit \ Assert = {
        let c = { attempts = 4, base = Util.Duration.fromMillis(1000), cap = Util.Duration.fromMillis(30000) };
        Assert.assertTrue(Retry.backoff(c, 0, 0) == Util.Duration.zero());
        Assert.assertTrue(Retry.backoff(c, 0, -5) == Util.Duration.zero());
        Assert.assertTrue(Retry.backoff(c, 0, 500) == Util.Duration.fromMillis(500));
        Assert.assertTrue(Retry.backoff(c, 0, 1200) == Util.Duration.fromMillis(999))
    }

    /// The wait is given the backoff's duration rather than reaching for a clock,
    /// so a test sees how long each try would have waited.
    @Test
    def theWaitIsGivenTheBackoffItWouldSleep(): Unit \ Assert =
        region rc {
            let waits = Ref.fresh(rc, (Nil: List[Int32]));
            let c = { attempts = 3, base = Util.Duration.fromMillis(1000), cap = Util.Duration.fromMillis(30000) };
            discard Retry.retryingWith(c, ms -> Ref.put(ms :: Ref.get(waits), waits), _ -> 500, () ->
                DbErr.raise(DbError.unreachable("connection refused")));
            Assert.assertTrue(List.reverse(Ref.get(waits)) == 1000 :: 2000 :: Nil)
        }

    /// A first try that answers is the only try.
    @Test
    def anAnswerIsNotTriedAgain(): Unit \ Assert =
        region rc {
            let calls = Ref.fresh(rc, 0);
            let outcome = Retry.retryingWith(Retry.immediate(3), _ -> (), _ -> 500, () -> {
                Ref.put(Ref.get(calls) + 1, calls);
                "done"
            });
            Assert.assertTrue(outcome == Ok("done") and Ref.get(calls) == 1)
        }

    /// A failure the same statement may get past is tried again, and the last
    /// one is what comes back once the tries run out.
    @Test
    def aTransientFailureIsTriedAgainUntilTheTriesRunOut(): Unit \ Assert =
        region rc {
            let calls = Ref.fresh(rc, 0);
            let outcome = Retry.retryingWith(Retry.immediate(3), _ -> (), _ -> 500, () -> {
                Ref.put(Ref.get(calls) + 1, calls);
                DbErr.raise(DbError.unreachable("connection refused"))
            });
            Assert.assertTrue(
                (match outcome {
                    case Err(Failure.Transient(TransientKind.Unreachable(_))) => true
                    case _ => false
                })
                    and Ref.get(calls) == 3
            )
        }

    /// A failure the same statement reaches again comes back at once.
    @Test
    def aPermanentFailureIsNotTriedAgain(): Unit \ Assert =
        region rc {
            let calls = Ref.fresh(rc, 0);
            let outcome = Retry.retryingWith(Retry.immediate(3), _ -> (), _ -> 500, () -> {
                Ref.put(Ref.get(calls) + 1, calls);
                DbErr.raise(DbErrorKind.Other("no such table: laps"))
            });
            Assert.assertTrue(
                (match outcome {
                    case Err(Failure.Permanent(DbErrorKind.Other(_))) => true
                    case _ => false
                })
                    and Ref.get(calls) == 1
            )
        }

    /// A lock the database waited out is worth another try, and the try is made
    /// from the savepoint rather than from where the failed one got to.
    @Test
    def aSavepointIsTakenBackToBeforeTheNextTry(): Unit \ Assert = {
        let (outcome, sent) = Recording.statements(() ->
            DbError.runWithKind(() ->
                Retry.retryingSavepointWith("round", Retry.immediate(2), _ -> (), _ -> 500, () ->
                    DbErr.raise(DbError.busy("database is locked")))));
        let names = sent |> List.filterMap(s ->
            match s {
                case Statement.Execute(sql, _) => Some(sql)
                case Statement.InsertMany(_, _) => None
                case Statement.Fetch(_, _) => None
                case Statement.Commit => None
                case Statement.Rollback => None
            });
        Assert.assertTrue(
            (match outcome {
                case Ok(Err(Failure.Transient(TransientKind.Busy(_)))) => true
                case _ => false
            })
                and names == List.flatten(List.repeat(2,
                    "SAVEPOINT round" :: "ROLLBACK TO SAVEPOINT round" ::
                        "RELEASE SAVEPOINT round" :: Nil))
        )
    }

    /// A savepoint that is released is not taken back to.
    @Test
    def aSavepointThatAnswersIsReleased(): Unit \ Assert = {
        let (outcome, sent) = Recording.statements(() ->
            DbError.runWithKind(() ->
                Retry.retryingSavepointWith("round", Retry.immediate(3), _ -> (), _ -> 500, () -> 7)));
        Assert.assertTrue(
            outcome == Ok(Ok(7))
                and List.map(s -> match s {
                    case Statement.Execute(sql, _) => sql
                    case _ => "?"
                }, sent)
                    == "SAVEPOINT round" :: "RELEASE SAVEPOINT round" :: Nil
        )
    }

}
