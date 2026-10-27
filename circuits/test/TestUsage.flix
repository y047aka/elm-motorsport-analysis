/// The one flag every word takes. `--help` rides in each command's own
/// descriptor list, so the flag table is the proof: a command that stopped
/// declaring it loses it from its usage too, and the usage that answers the flag
/// is built from the same list. Which of its three answers a run of tokens comes
/// to is read here rather than run, `Cli.Args.Parsed` handing `--help` and a wrong
/// argument back as values and printing neither.
///
/// Which words there are at all is `Cli.Words`'s, and the usage-wide assertions walk
/// that list, so a word added to the jar is held to them without a test being written.
/// The assertions that name a command by hand are the ones reading its arguments, which
/// no table can carry.
///
/// What the table cannot be asked is whether a command module joined it at all: a
/// module's run is reached only through a case, and no compiler sees a case that was
/// never written. That is `app/tests/geometry-words.spec.ts`'s, read out of the sources.
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

    /// Every word the jar answers to declares the help flag, and declares it in the
    /// usage that is printed for it: the flag table is the proof, so a word that
    /// stopped declaring `--help` loses it from its own usage too, and a word missing
    /// from the list is a word no run can reach at all.
    @Test
    def testEveryGeometryWordDeclaresItsHelpFlag(): Unit \ Assert =
        foreach (one <- Cli.Words.words())
            Assert.assertTrueWithMsg(
                saysHelp(Cli.Words.usage(one)),
                "${Cli.Words.name(one)}: its usage names no --help"
            )

    /// One dialect at every usage: a reader who mistypes a word is answered with all
    /// of them at once, so they should read as one command's help rather than as six
    /// programs'.
    @Test
    def testEveryUsageLineOpensTheSameWay(): Unit \ Assert =
        foreach (one <- Cli.Words.words())
            Assert.assertTrueWithMsg(
                String.startsWith({prefix = "usage: nix run .#geometry -- "}, Cli.Words.usage(one)),
                "${Cli.Words.name(one)}: ${Cli.Words.usage(one)}"
            )

    /// The word a usage is listed under is the word the usage names. A table pairs a
    /// name, a run and a help line by hand, and the mistake it can make is a pairing:
    /// a word refused with another word's usage, which is a reader told to look at the
    /// wrong program's flags.
    @Test
    def testEveryUsageNamesTheWordItIsListedUnder(): Unit \ Assert =
        foreach (one <- Cli.Words.words())
            Assert.assertTrueWithMsg(
                String.contains({substr = "-- ${Cli.Words.name(one)} "}, Cli.Words.usage(one)),
                "the usage listed under ${Cli.Words.name(one)} does not name it: ${Cli.Words.usage(one)}"
            )

    /// The survey's and the atlas's usages are the one place a reader learns the
    /// flag that raises the network: a descriptor dropped from the flag table drops
    /// out of the help too, and the help line names the word it belongs to.
    @Test
    def testTheSurveyUsageNamesTheFlagThatRaisesTheNetwork(): Unit \ Assert =
        Assert.assertTrue(String.contains({substr = "-- survey <circuit>"}, Survey.usage()));
        Assert.assertTrue(String.contains({substr = "[--fetch]"}, Survey.usage()));
        Assert.assertTrue(String.contains({substr = "[--fetch]"}, Atlas.usage()))

    /// Every word answers `--help` before its own completing reads a word, which is
    /// what makes `atlas --help` the help and not the refusal of a run that named no
    /// circuit, and `timing-lines --help` the help and not the refusal of a run that
    /// named no `--csv` nor a round. These walk the commands by hand rather than the
    /// list above: a word's `arguments` answers in that word's own type, so the list
    /// that pairs a run and a usage carries none of them.
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
