/// The driver's codes, read with no driver: the extended ones carry the primary
/// code in their low byte, so `SQLITE_BUSY_SNAPSHOT` is a lock like
/// `SQLITE_BUSY` is.
///
/// A constraint is one code and four refusals, and the driver answers some of
/// them with the primary code alone, which is why the message is read too.
pub mod Db.TestSqlite {
    use Lite3fx.DbError
    use Lite3fx.DbError.DbErrorKind
    use Lite3fx.SqliteState

    def code(c: Int32): {code = Int32, message = String} = {code = c, message = "locked"}

    @Test
    def aLockIsTheOneRefusalThatSaysTryAgain(): Unit \ Assert =
        Assert.assertTrue(SqliteState.classify(code(5)) == DbError.busy("locked"));
        Assert.assertTrue(SqliteState.classify(code(6)) == DbError.busy("locked"));
        Assert.assertTrue(SqliteState.classify(code(517)) == DbError.busy("locked"));
        Assert.assertTrue(SqliteState.classify({code = 517, message = "snapshot"}) == DbError.busy("snapshot"))

    @Test
    def aMissingTableOrColumnNamesTheSchema(): Unit \ Assert =
        Assert.assertTrue(
            SqliteState.classify({code = 1, message = "no such table: laps"})
                == DbErrorKind.SchemaMismatch("no such table: laps"));
        Assert.assertTrue(
            SqliteState.classify({code = 1, message = "no such column: laps.s1_ms"})
                == DbErrorKind.SchemaMismatch("no such column: laps.s1_ms"));
        Assert.assertTrue(
            SqliteState.classify({code = 1, message = "near \"FORM\": syntax error"})
                == DbErrorKind.Other("near \"FORM\": syntax error"))

    /// The extended code says which constraint it is where the driver gave one.
    @Test
    def theExtendedCodeSaysWhichConstraint(): Unit \ Assert =
        Assert.assertTrue(
            SqliteState.classify({code = 2067, message = "UNIQUE constraint failed: laps.round_id"})
                == DbErrorKind.UniqueViolation("laps.round_id"));
        Assert.assertTrue(
            SqliteState.classify({code = 1555, message = "UNIQUE constraint failed: rounds.id"})
                == DbErrorKind.UniqueViolation("rounds.id"));
        Assert.assertTrue(
            SqliteState.classify({code = 1299, message = "NOT NULL constraint failed: laps.season"})
                == DbErrorKind.NotNullViolation("laps.season"));
        Assert.assertTrue(
            SqliteState.classify({code = 275, message = "CHECK constraint failed: flag_at_fl"})
                == DbErrorKind.CheckViolation("flag_at_fl"));
        Assert.assertTrue(
            SqliteState.classify({code = 787, message = "FOREIGN KEY constraint failed"})
                == DbErrorKind.ForeignKeyViolation("FOREIGN KEY constraint failed"))

    /// The driver answers most constraints with the primary code alone, and then
    /// the message is where the constraint is named.
    @Test
    def theMessageSaysWhichConstraintWhereTheCodeDoesNot(): Unit \ Assert =
        Assert.assertTrue(
            SqliteState.classify({code = 19, message = "UNIQUE constraint failed: laps.round_id"})
                == DbErrorKind.UniqueViolation("laps.round_id"));
        Assert.assertTrue(
            SqliteState.classify({code = 19, message = "FOREIGN KEY constraint failed"})
                == DbErrorKind.ForeignKeyViolation("FOREIGN KEY constraint failed"));
        Assert.assertTrue(
            SqliteState.classify({code = 19, message = "NOT NULL constraint failed: laps.season"})
                == DbErrorKind.NotNullViolation("laps.season"));
        Assert.assertTrue(
            SqliteState.classify({code = 19, message = "CHECK constraint failed: flag_at_fl"})
                == DbErrorKind.CheckViolation("flag_at_fl"))

    @Test
    def everyOtherCodeIsTheDriversOwnSentence(): Unit \ Assert =
        Assert.assertTrue(
            SqliteState.classify({code = 1555, message = "constraint"}) == DbErrorKind.UniqueViolation("constraint"));
        Assert.assertTrue(
            SqliteState.classify({code = 14, message = "unable to open database file"})
                == DbErrorKind.Other("unable to open database file"))

}
