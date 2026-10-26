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
        Assert.assertTrue(saysHelp(Fetch.usage()));
        Assert.assertTrue(saysHelp(Write.usage()));
        Assert.assertTrue(saysHelp(Write.writeUsage()));
        Assert.assertTrue(saysHelp(Atlas.usage()));
        Assert.assertTrue(saysHelp(Diff.usage()));
        Assert.assertTrue(saysHelp(Regenerate.usage()))

    /// The survey and the whole run take the flags unchanged, and each says
    /// which of them it is even in the help.
    @Test
    def testTheHelpLinesSayWhichWordTheyBelongTo(): Unit \ Assert =
        Assert.assertTrue(String.contains({substr = "-- survey <circuit>"}, Write.usage()));
        Assert.assertTrue(String.contains({substr = "-- write <circuit>"}, Write.writeUsage()))
}
