pub mod Db.TestRetry {

    /// The window a try waits inside doubles per try and stops at the ceiling.
    @Test
    def theWindowDoublesAndStopsAtTheCeiling(): Unit \ Assert = {
        let c = { attempts = 4, base = Util.Duration.fromMillis(1000), cap = Util.Duration.fromMillis(5000) };
        Assert.assertTrue(Db.Retry.backoff(c, 0, 999) == Util.Duration.fromMillis(999));
        Assert.assertTrue(Db.Retry.backoff(c, 1, 999) == Util.Duration.fromMillis(1998));
        Assert.assertTrue(Db.Retry.backoff(c, 2, 999) == Util.Duration.fromMillis(3996));
        Assert.assertTrue(Db.Retry.backoff(c, 3, 999) == Util.Duration.fromMillis(4995));
        Assert.assertTrue(Db.Retry.backoff(c, 9, 999) == Util.Duration.fromMillis(4995))
    }

    /// Full jitter draws from the whole window, so a draw of nothing waits
    /// nothing and a draw past the window is held inside it.
    @Test
    def theDrawIsHeldInsideTheWindow(): Unit \ Assert = {
        let c = { attempts = 4, base = Util.Duration.fromMillis(1000), cap = Util.Duration.fromMillis(30000) };
        Assert.assertTrue(Db.Retry.backoff(c, 0, 0) == Util.Duration.zero());
        Assert.assertTrue(Db.Retry.backoff(c, 0, -5) == Util.Duration.zero());
        Assert.assertTrue(Db.Retry.backoff(c, 0, 500) == Util.Duration.fromMillis(500));
        Assert.assertTrue(Db.Retry.backoff(c, 0, 1200) == Util.Duration.fromMillis(999))
    }

    /// The wait is given the backoff's duration rather than reaching for a clock,
    /// so a test sees how long each try would have waited.
    @Test
    def theWaitIsGivenTheBackoffItWouldSleep(): Unit \ Assert =
        region rc {
            let waits = Ref.fresh(rc, (Nil: List[Int32]));
            let c = { attempts = 3, base = Util.Duration.fromMillis(1000), cap = Util.Duration.fromMillis(30000) };
            discard Db.Retry.retryingWith(c, ms -> Ref.put(ms :: Ref.get(waits), waits), _ -> 500, () ->
                DbErr.raise(Db.unreachable("connection refused")));
            Assert.assertTrue(List.reverse(Ref.get(waits)) == 1000 :: 2000 :: Nil)
        }

    /// A first try that answers is the only try.
    @Test
    def anAnswerIsNotTriedAgain(): Unit \ Assert =
        region rc {
            let calls = Ref.fresh(rc, 0);
            let outcome = Db.Retry.retryingWith(Db.Retry.immediate(3), _ -> (), _ -> 500, () -> {
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
            let outcome = Db.Retry.retryingWith(Db.Retry.immediate(3), _ -> (), _ -> 500, () -> {
                Ref.put(Ref.get(calls) + 1, calls);
                DbErr.raise(Db.unreachable("connection refused"))
            });
            Assert.assertTrue(
                (match outcome {
                    case Err(Db.Failure.Transient(Db.Transient.Unreachable(_))) => true
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
            let outcome = Db.Retry.retryingWith(Db.Retry.immediate(3), _ -> (), _ -> 500, () -> {
                Ref.put(Ref.get(calls) + 1, calls);
                DbErr.raise(Db.Error.Refused("no such table: laps"))
            });
            Assert.assertTrue(
                (match outcome {
                    case Err(Db.Failure.Permanent(Db.Error.Refused(_))) => true
                    case _ => false
                })
                    and Ref.get(calls) == 1
            )
        }

    /// A lock the database waited out is worth another try, and the try is made
    /// from the savepoint rather than from where the failed one got to.
    @Test
    def aSavepointIsTakenBackToBeforeTheNextTry(): Unit \ Assert = {
        let (outcome, sent) = Db.runRecording(() ->
            Db.runWithError(() ->
                Db.Retry.retryingSavepointWith("round", Db.Retry.immediate(2), _ -> (), _ -> 500, () ->
                    DbErr.raise(Db.busy("database is locked")))));
        let names = sent |> List.filterMap(s ->
            match s {
                case Db.Statement.Execute(sql, _) => Some(sql)
                case Db.Statement.InsertMany(_, _) => None
                case Db.Statement.Fetch(_, _) => None
                case Db.Statement.Commit => None
                case Db.Statement.Rollback => None
            });
        Assert.assertTrue(
            (match outcome {
                case Ok(Err(Db.Failure.Transient(Db.Transient.Busy(_)))) => true
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
        let (outcome, sent) = Db.runRecording(() ->
            Db.runWithError(() ->
                Db.Retry.retryingSavepointWith("round", Db.Retry.immediate(3), _ -> (), _ -> 500, () -> 7)));
        Assert.assertTrue(
            outcome == Ok(Ok(7))
                and List.map(s -> match s {
                    case Db.Statement.Execute(sql, _) => sql
                    case _ => "?"
                }, sent)
                    == "SAVEPOINT round" :: "RELEASE SAVEPOINT round" :: Nil
        )
    }

}
