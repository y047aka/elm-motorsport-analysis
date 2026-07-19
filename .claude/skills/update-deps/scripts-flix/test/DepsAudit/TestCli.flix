mod DepsAudit.TestCli {

    use Sys.Console
    use DepsAudit.Cli

    // Every subcommand is assembled from these combinators, so their
    // short-circuiting is what guarantees a failing step is never masked
    // by a later success and never runs work that shouldn't happen.

    @Test
    def testAppendConcatenatesBothStreams(): Unit \ Assert =
        let out = Cli.append(Cli.ok("a" :: Nil), Cli.ok("b" :: Nil));
        Assert.assertTrue(Cli.stdout(out) == "a" :: "b" :: Nil);
        Assert.assertTrue(Cli.exitCode(out) == 0)

    /// A failure on the left is not cleared by success on the right.
    @Test
    def testAppendKeepsLeftFailure(): Unit \ Assert =
        let out = Cli.append(Cli.fail("boom"), Cli.ok("late success" :: Nil));
        Assert.assertTrue(Cli.exitCode(out) == 1);
        Assert.assertTrue(Cli.stderr(out) == "boom" :: Nil)

    @Test
    def testAppendPropagatesRightFailure(): Unit \ Assert =
        let out = Cli.append(Cli.ok("partial" :: Nil), Cli.fail("boom"));
        Assert.assertTrue(Cli.exitCode(out) == 1);
        // output produced before the failure is still reported
        Assert.assertTrue(Cli.stdout(out) == "partial" :: Nil)

    @Test
    def testFromResultOk(): Unit \ Assert =
        let out = Cli.fromResult(Ok("body"));
        Assert.assertTrue(Cli.stdout(out) == "body" :: Nil);
        Assert.assertTrue(Cli.exitCode(out) == 0)

    @Test
    def testFromResultErr(): Unit \ Assert =
        let out = Cli.fromResult(Err("bad"));
        Assert.assertTrue(Cli.stderr(out) == "bad" :: Nil);
        Assert.assertTrue(Cli.exitCode(out) == 1);
        Assert.assertTrue(List.isEmpty(Cli.stdout(out)))

    @Test
    def testFromResultWithDecidesFromValue(): Unit \ Assert =
        let out = Cli.fromResultWith(n -> Cli.okText("n=${n}"), Ok(7));
        Assert.assertTrue(Cli.stdout(out) == "n=7" :: Nil)

    @Test
    def testAndThenRunsOnSuccess(): Unit \ Assert =
        let out = Cli.okText("first") |> Cli.andThen(() -> Cli.okText("second"));
        Assert.assertTrue(Cli.stdout(out) == "first" :: "second" :: Nil)

    /// The continuation must not run at all once something has failed.
    @Test
    def testAndThenSkippedAfterFailure(): Unit \ Assert = region rc {
        let ran = Ref.fresh(rc, false);
        let out = Cli.fail("stop") |> Cli.andThen(() -> { Ref.put(true, ran); Cli.okText("should not appear") });
        Assert.assertTrue(not Ref.get(ran));
        Assert.assertTrue(List.isEmpty(Cli.stdout(out)));
        Assert.assertTrue(Cli.exitCode(out) == 1)
    }

    @Test
    def testTraverseUntilFailureConcatenatesAll(): Unit \ Assert =
        let out = Cli.traverseUntilFailure(x -> Cli.okText(x), "a" :: "b" :: "c" :: Nil);
        Assert.assertTrue(Cli.stdout(out) == "a" :: "b" :: "c" :: Nil);
        Assert.assertTrue(Cli.exitCode(out) == 0)

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
        Assert.assertTrue(Cli.stdout(out) == "a" :: Nil);
        Assert.assertTrue(Cli.stderr(out) == "failed at b" :: Nil);
        Assert.assertTrue(Cli.exitCode(out) == 1)
    }

    @Test
    def testTraverseUntilFailureEmptyList(): Unit \ Assert =
        let out = Cli.traverseUntilFailure(x -> Cli.okText(x), (Nil: List[String]));
        Assert.assertTrue(List.isEmpty(Cli.stdout(out)));
        Assert.assertTrue(Cli.exitCode(out) == 0)

    /// The SemiGroup/Monoid instances delegate to `append`/`empty` (covered
    /// above); this only checks they are wired up for stdlib combinators.
    @Test
    def testFoldableFoldConcatenates(): Unit \ Assert =
        let out = Foldable.fold(Cli.okText("a") :: Cli.okText("b") :: Nil);
        Assert.assertTrue(Cli.stdout(out) == "a" :: "b" :: Nil)

    // --- process boundary ---
    //
    // The stdlib `Console` effect is the standard way to reach this
    // process's stdin, and — being an effect — it can be served from
    // memory just like `FileIO`: no custom stdin abstraction needed.

    /// Run `f` with a Console whose stdin yields `lines` and whose
    /// prints are swallowed.
    def withStdin(lines: List[String], f: Unit -> a \ ef): a \ ef - Console = region rc {
        let remaining = Ref.fresh(rc, lines);
        run { f() } with handler Console {
            def readln(k) = match Ref.get(remaining) {
                case Nil     => k(None)
                case l :: ls => { Ref.put(ls, remaining); k(Some(l)) }
            }
            def print(_, k)    = k()
            def eprint(_, k)   = k()
            def println(_, k)  = k()
            def eprintln(_, k) = k()
        }
    }

    @Test
    def testReadStdinJoinsLines(): Unit \ Assert =
        Assert.assertEq(expected = "a\nb", withStdin("a" :: "b" :: Nil, () -> Cli.readStdin()))

    @Test
    def testReadStdinEmptyInput(): Unit \ Assert =
        Assert.assertEq(expected = "", withStdin(Nil, () -> Cli.readStdin()))

}
