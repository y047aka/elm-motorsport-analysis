mod DepsAudit.TestSemver {

    use DepsAudit.Semver


    @Test
    def testBaseVersionCaret(): Unit \ Assert =
        Assert.assertTrue(Semver.baseVersion("^1.2.3") == "1.2.3")

    @Test
    def testBaseVersionCompound(): Unit \ Assert =
        Assert.assertTrue(Semver.baseVersion(">=0.8") == "0.8")

    @Test
    def testBaseVersionPlain(): Unit \ Assert =
        Assert.assertTrue(Semver.baseVersion("2.0") == "2.0")

    @Test
    def testMajorComponentLeading(): Unit \ Assert =
        Assert.assertTrue(Semver.majorComponent("1.2.3") == (0, 1i64))

    @Test
    def testMajorComponentZeroLeading(): Unit \ Assert =
        Assert.assertTrue(Semver.majorComponent("0.8.1") == (1, 8i64))

    @Test
    def testMajorComponentAllZero(): Unit \ Assert =
        Assert.assertTrue(Semver.majorComponent("0.0.0") == (0, 0i64))

    @Test
    def testIsMajorBumpSimple(): Unit \ Assert =
        Assert.assertTrue(Semver.isMajorBump("1.2", "2.0"))

    @Test
    def testIsMajorBumpZeroSeries(): Unit \ Assert =
        Assert.assertTrue(Semver.isMajorBump("0.8", "0.9"))

    @Test
    def testIsMajorBumpPositionShift(): Unit \ Assert =
        Assert.assertTrue(Semver.isMajorBump("0.9", "1.0"))

    @Test
    def testIsMajorBumpFalseForMinor(): Unit \ Assert =
        Assert.assertTrue(not Semver.isMajorBump("1.2", "1.3"))

    @Test
    def testIsMinorBumpTrue(): Unit \ Assert =
        Assert.assertTrue(Semver.isMinorBump("1.2.0", "1.3.0"))

    @Test
    def testIsMinorBumpFalseForPatch(): Unit \ Assert =
        Assert.assertTrue(not Semver.isMinorBump("1.2.0", "1.2.5"))

    @Test
    def testIsMinorBumpZeroSeries(): Unit \ Assert =
        Assert.assertTrue(Semver.isMinorBump("0.11.10", "0.11.11"))

    // --- the Semver type: Eq/Order agree, trailing zeros are normalized ---

    @Test
    def testParseNormalizesTrailingZeros(): Unit \ Assert =
        Assert.assertTrue(Semver.parse("1.2") == Semver.parse("1.2.0"))

    @Test
    def testOrderSortsVersionStrings(): Unit \ Assert =
        let sorted = List.sortBy(Semver.parse, "12.3.0" :: "9.9.9" :: "12.1.2" :: Nil);
        Assert.assertTrue(sorted == "9.9.9" :: "12.1.2" :: "12.3.0" :: Nil)

    @Test
    def testOrderNumericNotLexicographic(): Unit \ Assert =
        Assert.assertTrue(Order.compare(Semver.parse("1.10"), Semver.parse("1.9")) == Comparison.GreaterThan)

}
