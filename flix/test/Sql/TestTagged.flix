mod Sql.TestTagged {

    use Sql.Branch

    def branches(): List[Branch[String]] =
        Branch.One("fastest lap", Sql.raw("t FROM laps")) ::
        Branch.One("slowest lap", Sql.raw("t FROM laps")) ::
        Branch.Many(
            {
                span   = 3,
                number = Sql.column("m.key"),
                tagOf  = key -> if (key >= 0 and key < 3) Some("marker ${key + 1}") else None
            },
            Sql.raw("m.value FROM laps, json_each(laps.mini_sector_time_ms) m")
        ) ::
        Nil

    /// The arms are numbered in the order given, an arm about several things
    /// taking as many numbers as it says.
    @Test
    def eachArmCarriesTheNumberItWasGiven(): Unit \ Assert =
        let (rows, _) = Sql.unionAllTagged("k", branches());
        Assert.assertTrue(Sql.toSql(rows) == (
            "SELECT 0 AS k, t FROM laps"
                + " UNION ALL SELECT 1 AS k, t FROM laps"
                + " UNION ALL SELECT 2 + m.key AS k, m.value"
                + " FROM laps, json_each(laps.mini_sector_time_ms) m",
            Nil
        ))

    @Test
    def theReadingTurnsTheNumberBackIntoWhatTheArmWasAbout(): Unit \ Assert =
        let (_, tag) = Sql.unionAllTagged("k", branches());
        Assert.assertTrue(Sql.decode(tag, Some("0") :: Nil) == Ok("fastest lap"));
        Assert.assertTrue(Sql.decode(tag, Some("1") :: Nil) == Ok("slowest lap"));
        Assert.assertTrue(Sql.decode(tag, Some("2") :: Nil) == Ok("marker 1"));
        Assert.assertTrue(Sql.decode(tag, Some("4") :: Nil) == Ok("marker 3"))

    @Test
    def theReadingNamesTheColumnTheNumberIsCarriedIn(): Unit \ Assert =
        let (_, tag) = Sql.unionAllTagged("k", branches());
        Assert.assertTrue(Sql.toSql(Sql.clause(tag)) == ("SELECT k", Nil))

    @Test
    def aNumberNoArmAnswersToIsAnError(): Unit \ Assert =
        let (_, tag) = Sql.unionAllTagged("k", branches());
        Assert.assertTrue(Sql.decode(tag, Some("5") :: Nil) == Err("no arm answers to `k` 5"))

}
