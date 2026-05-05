mod Util.TestDuration {

    use Util.Duration

    @Test
    def testFromStringEmpty(): Unit \ Assert =
        Assert.assertTrue(Duration.fromString("") == None)

    @Test
    def testFromStringSecondsOnly(): Unit \ Assert =
        Assert.assertTrue(Duration.fromString("23.155") == Some(Duration.fromMillis(23155)))

    @Test
    def testFromStringMinutesSeconds(): Unit \ Assert =
        Assert.assertTrue(Duration.fromString("1:35.365") == Some(Duration.fromMillis(95365)))

    @Test
    def testFromStringHoursMinutesSeconds(): Unit \ Assert =
        Assert.assertTrue(Duration.fromString("1:02:05.001") == Some(Duration.fromMillis(3725001)))

    @Test
    def testFromStringInvalid(): Unit \ Assert =
        Assert.assertTrue(Duration.fromString("not-a-duration") == None)

    @Test
    def testFormatSecondsOnly(): Unit \ Assert =
        Assert.assertTrue(Duration.format(Duration.fromMillis(23155)) == "23.155")

    @Test
    def testFormatStripsLeadingZeroHour(): Unit \ Assert =
        Assert.assertTrue(Duration.format(Duration.fromMillis(101031)) == "1:41.031")

    @Test
    def testFormatStripsLeadingZeroHourAndMinute(): Unit \ Assert =
        Assert.assertTrue(Duration.format(Duration.fromMillis(48666)) == "48.666")

    @Test
    def testFormatHoursMinutesSeconds(): Unit \ Assert =
        Assert.assertTrue(Duration.format(Duration.fromMillis(3725001)) == "1:02:05.001")

    @Test
    def testToStringInstance(): Unit \ Assert =
        Assert.assertTrue("${Duration.fromMillis(95365)}" == "1:35.365")

    @Test
    def testAdd(): Unit \ Assert =
        let a = Duration.fromMillis(30000);
        let b = Duration.fromMillis(60000);
        Assert.assertTrue(Duration.add(a, b) == Duration.fromMillis(90000))

    @Test
    def testZero(): Unit \ Assert =
        Assert.assertTrue(Duration.zero() == Duration.fromMillis(0))

}
