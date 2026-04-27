mod TestDuration {

    @Test
    def testParseSecondsOnly(): Unit \ Assert =
        Assert.assertTrue(Duration.parse("23.155") == Some(23155))

    @Test
    def testParseMinutesSeconds(): Unit \ Assert =
        Assert.assertTrue(Duration.parse("1:35.365") == Some(95365))

    @Test
    def testParseHoursMinutesSeconds(): Unit \ Assert =
        Assert.assertTrue(Duration.parse("0:01:41.031") == Some(101031))

    @Test
    def testParseInvalid(): Unit \ Assert =
        Assert.assertTrue(Duration.parse("not-a-duration") == None)

    @Test
    def testFormatSecondsOnly(): Unit \ Assert =
        Assert.assertTrue(Duration.format(23155) == "23.155")

    @Test
    def testFormatMinutesSeconds(): Unit \ Assert =
        Assert.assertTrue(Duration.format(95365) == "1:35.365")

    @Test
    def testFormatHoursMinutesSeconds(): Unit \ Assert =
        Assert.assertTrue(Duration.format(3725001) == "1:02:05.001")

    @Test
    def testNormalizeStripsLeadingZeroSegments(): Unit \ Assert =
        Assert.assertTrue(Duration.normalize("0:01:41.031") == "1:41.031");
        Assert.assertTrue(Duration.normalize("0:00:48.666") == "48.666")

    @Test
    def testNormalizeKeepsCanonical(): Unit \ Assert =
        Assert.assertTrue(Duration.normalize("3:38.404") == "3:38.404");
        Assert.assertTrue(Duration.normalize("23.155") == "23.155")

    @Test
    def testNormalizeEmpty(): Unit \ Assert =
        Assert.assertTrue(Duration.normalize("") == "")

}
