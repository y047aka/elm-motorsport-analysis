/// The driver's codes, read with no driver: the extended ones carry the primary
/// code in their low byte, so `SQLITE_BUSY_SNAPSHOT` is a lock like
/// `SQLITE_BUSY` is.
pub mod Db.TestSqlite {

    use Db.Sqlite

    def code(c: Int32): {code = Int32, message = String} = {code = c, message = "locked"}

    @Test
    def aLockIsTheOneRefusalThatSaysTryAgain(): Unit \ Assert =
        Assert.assertTrue(Sqlite.classify(code(5)) == Db.busy("locked"));
        Assert.assertTrue(Sqlite.classify(code(6)) == Db.busy("locked"));
        Assert.assertTrue(Sqlite.classify(code(517)) == Db.busy("locked"));
        Assert.assertTrue(Sqlite.classify({code = 517, message = "snapshot"}) == Db.busy("snapshot"))

    @Test
    def everyOtherCodeIsTheDriversOwnSentence(): Unit \ Assert =
        Assert.assertTrue(
            Sqlite.classify({code = 1, message = "no such table: laps"})
                == Db.Error.Refused("no such table: laps"));
        Assert.assertTrue(
            Sqlite.classify({code = 1555, message = "constraint"}) == Db.Error.Refused("constraint"));
        Assert.assertTrue(
            Sqlite.classify({code = 2067, message = "FOREIGN KEY constraint failed"})
                == Db.Error.Refused("FOREIGN KEY constraint failed"))

}
