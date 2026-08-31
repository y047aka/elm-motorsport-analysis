mod Util.TestHourClock {

    use Util.HourClock
    use Util.HourClock.Hour

    @Test
    def testParseValidHms(): Unit \ Assert =
        match HourClock.parse("11:02:03.456") {
            case Ok(h)  => Assert.assertTrue(HourClock.msSinceMidnight(h) == 39723456)
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testParseEmptyIsErr(): Unit \ Assert =
        match HourClock.parse("") {
            case Err(raw) => Assert.assertTrue(raw == "")
            case Ok(_)    => Assert.assertTrue(false)
        }

    @Test
    def testParseTwoComponentRejected(): Unit \ Assert =
        // M:SS is not a time-of-day, so Err is expected
        match HourClock.parse("3:38.404") {
            case Err(_) => Assert.assertTrue(true)
            case Ok(_)  => Assert.assertTrue(false)
        }

    @Test
    def testParseTwentyFourHoursRejected(): Unit \ Assert =
        match HourClock.parse("24:00:00.000") {
            case Err(_) => Assert.assertTrue(true)
            case Ok(_)  => Assert.assertTrue(false)
        }

    @Test
    def testParseGarbageReturnsRaw(): Unit \ Assert =
        match HourClock.parse("not-a-time") {
            case Err(raw) => Assert.assertTrue(raw == "not-a-time")
            case Ok(_)    => Assert.assertTrue(false)
        }

    @Test
    def testFormatProducesZeroPaddedHms(): Unit \ Assert =
        match HourClock.parse("00:00:00.036") {
            case Ok(h)  => Assert.assertTrue(HourClock.format(h) == "00:00:00.036")
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testFormatLargeHour(): Unit \ Assert =
        match HourClock.parse("23:59:00.000") {
            case Ok(h)  => Assert.assertTrue(HourClock.format(h) == "23:59:00.000")
            case Err(_) => Assert.assertTrue(false)
        }

}
