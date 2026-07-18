mod DepsAudit.TestCli {

    use DepsAudit.Cli

    // Every subcommand is assembled from these combinators, so their
    // short-circuiting is what guarantees a failing step is never masked
    // by a later success and never runs work that shouldn't happen.

    @Test
    def testAppendConcatenatesBothStreams(): Unit \ Assert =
        let out = Cli.append(Cli.ok("a" :: Nil), Cli.ok("b" :: Nil));
        Assert.assertTrue(out#stdout == "a" :: "b" :: Nil);
        Assert.assertTrue(out#exitCode == 0)

    /// A failure on the left is not cleared by success on the right.
    @Test
    def testAppendKeepsLeftFailure(): Unit \ Assert =
        let out = Cli.append(Cli.fail("boom"), Cli.ok("late success" :: Nil));
        Assert.assertTrue(out#exitCode == 1);
        Assert.assertTrue(out#stderr == "boom" :: Nil)

    @Test
    def testAppendPropagatesRightFailure(): Unit \ Assert =
        let out = Cli.append(Cli.ok("partial" :: Nil), Cli.fail("boom"));
        Assert.assertTrue(out#exitCode == 1);
        // output produced before the failure is still reported
        Assert.assertTrue(out#stdout == "partial" :: Nil)

    @Test
    def testFromResultOk(): Unit \ Assert =
        let out = Cli.fromResult(Ok("body"));
        Assert.assertTrue(out#stdout == "body" :: Nil);
        Assert.assertTrue(out#exitCode == 0)

    @Test
    def testFromResultErr(): Unit \ Assert =
        let out = Cli.fromResult(Err("bad"));
        Assert.assertTrue(out#stderr == "bad" :: Nil);
        Assert.assertTrue(out#exitCode == 1);
        Assert.assertTrue(List.isEmpty(out#stdout))

    @Test
    def testFromResultWithDecidesFromValue(): Unit \ Assert =
        let out = Cli.fromResultWith(n -> Cli.okText("n=${n}"), Ok(7));
        Assert.assertTrue(out#stdout == "n=7" :: Nil)

    @Test
    def testAndThenRunsOnSuccess(): Unit \ Assert =
        let out = Cli.okText("first") |> Cli.andThen(() -> Cli.okText("second"));
        Assert.assertTrue(out#stdout == "first" :: "second" :: Nil)

    /// The continuation must not run at all once something has failed.
    @Test
    def testAndThenSkippedAfterFailure(): Unit \ Assert = region rc {
        let ran = Ref.fresh(rc, false);
        let out = Cli.fail("stop") |> Cli.andThen(() -> { Ref.put(true, ran); Cli.okText("should not appear") });
        Assert.assertTrue(not Ref.get(ran));
        Assert.assertTrue(List.isEmpty(out#stdout));
        Assert.assertTrue(out#exitCode == 1)
    }

    @Test
    def testTraverseUntilFailureConcatenatesAll(): Unit \ Assert =
        let out = Cli.traverseUntilFailure(x -> Cli.okText(x), "a" :: "b" :: "c" :: Nil);
        Assert.assertTrue(out#stdout == "a" :: "b" :: "c" :: Nil);
        Assert.assertTrue(out#exitCode == 0)

    /// Keeps what succeeded, stops touching the rest.
    @Test
    def testTraverseUntilFailureStopsAtFirstFailure(): Unit \ Assert = region rc {
        let seen = Ref.fresh(rc, Nil);
        let step = x -> {
            Ref.put(x :: Ref.get(seen), seen);
            if (x == "b") Cli.fail("failed at b") else Cli.okText(x)
        };
        let out = Cli.traverseUntilFailure(step, "a" :: "b" :: "c" :: Nil);
        // "c" is never processed
        Assert.assertTrue(Ref.get(seen) == "b" :: "a" :: Nil);
        Assert.assertTrue(out#stdout == "a" :: Nil);
        Assert.assertTrue(out#stderr == "failed at b" :: Nil);
        Assert.assertTrue(out#exitCode == 1)
    }

    @Test
    def testTraverseUntilFailureEmptyList(): Unit \ Assert =
        let out = Cli.traverseUntilFailure(x -> Cli.okText(x), (Nil: List[String]));
        Assert.assertTrue(List.isEmpty(out#stdout));
        Assert.assertTrue(out#exitCode == 0)

}
