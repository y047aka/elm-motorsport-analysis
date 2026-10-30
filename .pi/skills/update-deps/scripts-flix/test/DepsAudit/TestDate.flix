mod DepsAudit.TestDate {

    use DepsAudit.Date


    @Test
    def testEpochDayZero(): Unit \ Assert =
        Assert.assertTrue(Date.daysToYmd(0i64) == (1970i64, 1i64, 1i64))

    @Test
    def testKnownDate(): Unit \ Assert =
        // 2026-04-07 (nixpkgs pin observed in flake.lock) = 20550 days.
        Assert.assertTrue(Date.daysToYmd(20550i64) == (2026i64, 4i64, 7i64))

    @Test
    def testLeapDay(): Unit \ Assert =
        // 2024-02-29 = 19782 days since epoch.
        Assert.assertTrue(Date.daysToYmd(19782i64) == (2024i64, 2i64, 29i64))

    @Test
    def testIsoFormat(): Unit \ Assert =
        Assert.assertTrue(Date.epochSecondsToIsoDate(1775072720i64) == "2026-04-01")

    @Test
    def testIsoFormatPadsMonthAndDay(): Unit \ Assert =
        Assert.assertTrue(Date.epochSecondsToIsoDate(0i64) == "1970-01-01")

}
