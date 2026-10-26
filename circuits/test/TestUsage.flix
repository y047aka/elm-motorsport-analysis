/// The one flag every word takes. `--help` rides in each command's own
/// descriptor list, so the flag table is the proof: a command that stopped
/// declaring it loses it from its usage too, and the answering — which no
/// pure test reaches, being the run's own printing — asks only that the
/// usage says it.
pub mod TestUsage {

    def saysHelp(usage: String): Bool =
        String.contains({substr = "--help"}, usage)

    @Test
    def testEveryGeometryWordDeclaresItsHelpFlag(): Unit \ Assert =
        Assert.assertTrue(saysHelp(Write.usage()));
        Assert.assertTrue(saysHelp(Atlas.usage()));
        Assert.assertTrue(saysHelp(Diff.usage()));
        Assert.assertTrue(saysHelp(Regenerate.usage()));
        Assert.assertTrue(saysHelp(Probe.usage()));
        Assert.assertTrue(saysHelp(Report.usage()))

    /// The survey's usage is the one place a reader learns the flag that raises the
    /// network: a descriptor dropped from the flag table drops out of the help too,
    /// and the help line names the word it belongs to.
    @Test
    def testTheSurveyUsageNamesTheFlagThatRaisesTheNetwork(): Unit \ Assert =
        Assert.assertTrue(String.contains({substr = "-- survey <circuit>"}, Write.usage()));
        Assert.assertTrue(String.contains({substr = "[--fetch]"}, Write.usage()))
}
