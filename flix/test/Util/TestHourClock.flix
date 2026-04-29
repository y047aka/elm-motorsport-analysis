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
        // M:SS は時刻ではないので Err
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
    def testOffsetFromBasic(): Unit \ Assert =
        // 14:02:00.000 - 2:00.000 = 14:00:00.000 = 50400000 ms
        match HourClock.parse("14:02:00.000") {
            case Ok(h)  => Assert.assertTrue(HourClock.offsetFrom(h, 120000) == 50400000)
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testOffsetFromMidnightWrap(): Unit \ Assert =
        // race start 16:00:00.000, after 8h elapsed hour = 00:00:00.000
        // (0 - 8h) mod 24h = 16h = 57600000 ms
        match HourClock.parse("00:00:00.000") {
            case Ok(h) =>
                let elapsed = 8 * 3600 * 1000;
                Assert.assertTrue(HourClock.offsetFrom(h, elapsed) == 57600000)
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testOffsetFromSameWallClockBeforeAndAfterMidnight(): Unit \ Assert =
        // 23:59:00.000 - 1:00.000 = 23:58:00.000
        // 0:01:00.000 - 3:00.000 = -2:00 mod 24h = 23:58:00.000 (wrap-aware)
        let beforeRes = HourClock.parse("23:59:00.000");
        let afterRes  = HourClock.parse("0:01:00.000");
        match (beforeRes, afterRes) {
            case (Ok(b), Ok(a)) =>
                Assert.assertTrue(HourClock.offsetFrom(b, 60000) == HourClock.offsetFrom(a, 180000))
            case _ => Assert.assertTrue(false)
        }

}
