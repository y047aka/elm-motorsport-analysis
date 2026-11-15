pub mod Db.TestRetry {

    /// The window a try waits inside doubles per try and stops at the ceiling.
    @Test
    def theWindowDoublesAndStopsAtTheCeiling(): Unit \ Assert = {
        let c = Db.Retry.Config.Config(4, Util.Duration.fromMillis(1000), Util.Duration.fromMillis(5000));
        Assert.assertTrue(Db.Retry.backoff(0, c, 999) == Util.Duration.fromMillis(999));
        Assert.assertTrue(Db.Retry.backoff(1, c, 999) == Util.Duration.fromMillis(1998));
        Assert.assertTrue(Db.Retry.backoff(2, c, 999) == Util.Duration.fromMillis(3996));
        Assert.assertTrue(Db.Retry.backoff(3, c, 999) == Util.Duration.fromMillis(4995));
        Assert.assertTrue(Db.Retry.backoff(9, c, 999) == Util.Duration.fromMillis(4995))
    }

    /// Full jitter draws from the whole window, so a draw of nothing waits
    /// nothing and a draw past the window is held inside it.
    @Test
    def theDrawIsHeldInsideTheWindow(): Unit \ Assert = {
        let c = Db.Retry.Config.Config(4, Util.Duration.fromMillis(1000), Util.Duration.fromMillis(30000));
        Assert.assertTrue(Db.Retry.backoff(0, c, 0) == Util.Duration.zero());
        Assert.assertTrue(Db.Retry.backoff(0, c, -5) == Util.Duration.zero());
        Assert.assertTrue(Db.Retry.backoff(0, c, 500) == Util.Duration.fromMillis(500));
        Assert.assertTrue(Db.Retry.backoff(0, c, 1200) == Util.Duration.fromMillis(999))
    }

    /// A first try that answers is the only try.
    @Test
    def anAnswerIsNotTriedAgain(): Unit \ {Assert, IO} =
        region rc {
            let calls = Ref.fresh(rc, 0);
            let outcome = Db.Retry.retrying(Db.Retry.immediate(3), () -> {
                Ref.put(Ref.get(calls) + 1, calls);
                "done"
            });
            Assert.assertTrue(outcome == Ok("done") and Ref.get(calls) == 1)
        }

    /// A failure the same statement may get past is tried again, and the last
    /// one is what comes back once the tries run out.
    @Test
    def aTransientFailureIsTriedAgainUntilTheTriesRunOut(): Unit \ {Assert, IO} =
        region rc {
            let calls = Ref.fresh(rc, 0);
            let outcome = Db.Retry.retrying(Db.Retry.immediate(3), () -> {
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
    def aPermanentFailureIsNotTriedAgain(): Unit \ {Assert, IO} =
        region rc {
            let calls = Ref.fresh(rc, 0);
            let outcome = Db.Retry.retrying(Db.Retry.immediate(3), () -> {
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
    def aSavepointIsTakenBackToBeforeTheNextTry(): Unit \ {Assert, IO} = {
        let (outcome, sent) = Db.runRecording(() ->
            Db.runWithError(() ->
                Db.Retry.retryingSavepoint("round", Db.Retry.immediate(2), () ->
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
    def aSavepointThatAnswersIsReleased(): Unit \ {Assert, IO} = {
        let (outcome, sent) = Db.runRecording(() ->
            Db.runWithError(() ->
                Db.Retry.retryingSavepoint("round", Db.Retry.immediate(3), () -> 7)));
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
