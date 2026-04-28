mod Util.TestDuration {

    use Util.Duration

    @Test
    def testNormalizeKeepsSecondsOnly(): Unit \ Assert =
        Assert.assertTrue(Duration.normalize("23.155") == "23.155")

    @Test
    def testNormalizeKeepsMinutesSeconds(): Unit \ Assert =
        Assert.assertTrue(Duration.normalize("3:38.404") == "3:38.404")

    @Test
    def testNormalizeKeepsHoursMinutesSeconds(): Unit \ Assert =
        Assert.assertTrue(Duration.normalize("1:02:05.001") == "1:02:05.001")

    @Test
    def testNormalizeStripsLeadingZeroHour(): Unit \ Assert =
        Assert.assertTrue(Duration.normalize("0:01:41.031") == "1:41.031")

    @Test
    def testNormalizeStripsLeadingZeroHourAndMinute(): Unit \ Assert =
        Assert.assertTrue(Duration.normalize("0:00:48.666") == "48.666")

    @Test
    def testNormalizeEmpty(): Unit \ Assert =
        Assert.assertTrue(Duration.normalize("") == "")

    @Test
    def testNormalizeInvalidPassthrough(): Unit \ Assert =
        Assert.assertTrue(Duration.normalize("not-a-duration") == "not-a-duration")

    @Test
    def testToMillisEmpty(): Unit \ Assert =
        Assert.assertTrue(Duration.toMillis("") == None)

    @Test
    def testToMillisMinutesSeconds(): Unit \ Assert =
        Assert.assertTrue(Duration.toMillis("1:35.365") == Some(95365))

    @Test
    def testToMillisHoursMinutesSeconds(): Unit \ Assert =
        Assert.assertTrue(Duration.toMillis("6:10.938") == Some(370938))

    @Test
    def testToMillisInvalid(): Unit \ Assert =
        Assert.assertTrue(Duration.toMillis("not-a-duration") == None)

}
