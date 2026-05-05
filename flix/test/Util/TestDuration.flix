mod Util.TestDuration {

    use Util.Duration

    @Test
    def testToMillisEmpty(): Unit \ Assert =
        Assert.assertTrue(Duration.toMillis("") == None)

    @Test
    def testToMillisSecondsOnly(): Unit \ Assert =
        Assert.assertTrue(Duration.toMillis("23.155") == Some(23155))

    @Test
    def testToMillisMinutesSeconds(): Unit \ Assert =
        Assert.assertTrue(Duration.toMillis("1:35.365") == Some(95365))

    @Test
    def testToMillisHoursMinutesSeconds(): Unit \ Assert =
        Assert.assertTrue(Duration.toMillis("1:02:05.001") == Some(3725001))

    @Test
    def testToMillisInvalid(): Unit \ Assert =
        Assert.assertTrue(Duration.toMillis("not-a-duration") == None)

    @Test
    def testFormatSecondsOnly(): Unit \ Assert =
        Assert.assertTrue(Duration.format(23155) == "23.155")

    @Test
    def testFormatStripsLeadingZeroHour(): Unit \ Assert =
        Assert.assertTrue(Duration.format(101031) == "1:41.031")

    @Test
    def testFormatStripsLeadingZeroHourAndMinute(): Unit \ Assert =
        Assert.assertTrue(Duration.format(48666) == "48.666")

    @Test
    def testFormatHoursMinutesSeconds(): Unit \ Assert =
        Assert.assertTrue(Duration.format(3725001) == "1:02:05.001")

}
