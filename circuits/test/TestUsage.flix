/// The one flag every word takes. `--help` rides in each command's own
/// descriptor list, so the flag table is the proof: a command that stopped
/// declaring it loses it from its usage too, and the usage that answers the flag
/// is built from the same list. Which of its three answers a run of tokens comes
/// to is read here rather than run, `Cli.Args.Parsed` handing `--help` and a wrong
/// argument back as values and printing neither.
pub mod TestUsage {

    def saysHelp(usage: String): Bool =
        String.contains({substr = "--help"}, usage)

    def saysUsage(parsed: Cli.Args.Parsed[a]): Bool =
        match parsed {
            case Cli.Args.Parsed.Help(_)    => true
            case Cli.Args.Parsed.Refused(_) => false
            case Cli.Args.Parsed.Asked(_)   => false
        }

    def refusedWith(usage: String, parsed: Cli.Args.Parsed[a]): Bool =
        match parsed {
            case Cli.Args.Parsed.Refused({problem = _, usage = said}) => said == usage
            case _                                                   => false
        }

    @Test
    def testEveryGeometryWordDeclaresItsHelpFlag(): Unit \ Assert =
        Assert.assertTrue(saysHelp(Survey.usage()));
        Assert.assertTrue(saysHelp(Atlas.usage()));
        Assert.assertTrue(saysHelp(Diff.usage()));
        Assert.assertTrue(saysHelp(Regenerate.usage()));
        Assert.assertTrue(saysHelp(Probe.usage()));
        Assert.assertTrue(saysHelp(Report.usage()))

    /// The survey's and the atlas's usages are the one place a reader learns the
    /// flag that raises the network: a descriptor dropped from the flag table drops
    /// out of the help too, and the help line names the word it belongs to.
    @Test
    def testTheSurveyUsageNamesTheFlagThatRaisesTheNetwork(): Unit \ Assert =
        Assert.assertTrue(String.contains({substr = "-- survey <circuit>"}, Survey.usage()));
        Assert.assertTrue(String.contains({substr = "[--fetch]"}, Survey.usage()));
        Assert.assertTrue(String.contains({substr = "[--fetch]"}, Atlas.usage()))

    /// One dialect at every usage: a reader who mistypes a word is answered with all
    /// of them at once, so they should read as one command's help rather than as six
    /// programs'.
    @Test
    def testEveryUsageLineOpensTheSameWay(): Unit \ Assert =
        foreach (
            usage <-
                Survey.usage() ::
                    Atlas.usage() ::
                    Diff.usage() ::
                    Probe.usage() ::
                    Regenerate.usage() ::
                    Report.usage() ::
                    Nil
        )
            Assert.assertTrue(String.startsWith({prefix = "usage: nix run .#geometry -- "}, usage))

    /// Every word answers `--help` before its own completing reads a word, which is
    /// what makes `atlas --help` the help and not the refusal of a run that named no
    /// circuit, and `timing-lines --help` the help and not the refusal of a run that
    /// named no `--csv` nor a round.
    @Test
    def testEveryWordAnswersHelpBeforeItReadsAWordOfItsOwn(): Unit \ Assert =
        Assert.assertTrue(saysUsage(Survey.arguments("--help" :: Nil)));
        Assert.assertTrue(saysUsage(Atlas.arguments("--help" :: Nil)));
        Assert.assertTrue(saysUsage(Diff.arguments("--help" :: Nil)));
        Assert.assertTrue(saysUsage(Probe.arguments("--help" :: Nil)));
        Assert.assertTrue(saysUsage(Regenerate.arguments("--help" :: Nil)));
        Assert.assertTrue(saysUsage(Report.arguments("--help" :: Nil)))

    /// Two flags that cannot answer for one run are judged after `--help`, so a run
    /// that raised `--write` against `--freeze` and asked for help as well is
    /// answered rather than refused.
    @Test
    def testHelpIsAnsweredWhereTwoFlagsContradict(): Unit \ Assert =
        Assert.assertTrue(saysUsage(Regenerate.arguments("--write" :: "--freeze" :: "--help" :: Nil)))

    /// A wrong argument is refused with the usage of the command it was given to,
    /// which is the one naming the flags that were not typed. A refusal naming
    /// another command's usage is a reader told to look at the wrong program.
    @Test
    def testAWrongArgumentIsRefusedWithItsOwnUsage(): Unit \ Assert =
        Assert.assertTrue(refusedWith(Survey.usage(), Survey.arguments("cota" :: "--froze" :: Nil)));
        Assert.assertTrue(refusedWith(Atlas.usage(), Atlas.arguments("cota" :: "--file" :: "--fetch" :: Nil)));
        Assert.assertTrue(refusedWith(Report.usage(), Report.arguments("--serve" :: "2026/cota_6h" :: Nil)))

    /// Arguments the command can ask with reach the run as the asking they are, which
    /// is the one case that is neither usage.
    @Test
    def testGoodArgumentsReachTheRun(): Unit \ Assert =
        Assert.assertTrue(
            match Survey.arguments("cota" :: "--write" :: Nil) {
                case Cli.Args.Parsed.Asked(asked) => asked#write and asked#circuit#word == "cota"
                case _                            => false
            }
        )
}
