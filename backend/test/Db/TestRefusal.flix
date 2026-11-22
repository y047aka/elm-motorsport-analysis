/// A statement the database refuses is reported with the statement it was asked in.
///
/// The driver names what it could not resolve and never the SQL it was written
/// into, which is the half a reader of a statement written out needs. A name the
/// database has not got and a sentence SQLite gave no name to at all are the two
/// kinds whose own message says nowhere to look, so both carry it; a constraint
/// names itself and does not.
pub mod Db.TestRefusal {

    use Lite3fx.DbError
    use Lite3fx.DbError.DbErrorKind
    use Lite3fx.Jdbc
    use Lite3fx.Row.Row
    use Round.TestSupport

    def refused(sql: String): Result[DbErrorKind, List[Row]] \ IO =
        DbError.runWithKind(() -> Jdbc.withConnection(TestSupport.url(), () ->
            Lite3fx.Sql.fetch(sql, Nil)
        ))

    @Test
    def aNameTheDatabaseHasNotGotCarriesTheStatementItWasAskedIn(): Unit \ Assert + IO =
        match refused("SELECT nope FROM laps WHERE round_id = 1") {
            case Err(DbErrorKind.SchemaMismatch(why)) => Assert.assertTrue(String.endsWith(
                {suffix = ": SELECT nope FROM laps WHERE round_id = 1"}, why
            ))
            case _ => Assert.assertTrue(false)
        }

    /// A keyword mistyped, which is what a statement written by hand gets wrong --
    /// and the kind whose message says nothing about where to look.
    @Test
    def aSyntaxErrorCarriesTheStatementItWasAskedIn(): Unit \ Assert + IO =
        match refused("SELCT elapsed_ms FROM laps WHERE round_id = 1") {
            case Err(DbErrorKind.Other(why)) => Assert.assertTrue(String.endsWith(
                {suffix = ": SELCT elapsed_ms FROM laps WHERE round_id = 1"}, why
            ))
            case _ => Assert.assertTrue(false)
        }

    /// A constraint names the constraint, which is more use than 220 characters of
    /// the statement that tripped it.
    @Test
    def aViolationNamesItselfAndNotTheStatement(): Unit \ Assert + IO =
        match Lite3fx.DbError.runWithKind(() -> Jdbc.withConnection(TestSupport.url(), () -> {
            discard Lite3fx.Sql.execute("CREATE TABLE t (k int unique)", Nil);
            discard Lite3fx.Sql.execute("INSERT INTO t VALUES (1)", Nil);
            Lite3fx.Sql.execute("INSERT INTO t VALUES (1)", Nil)
        })) {
            case Err(DbErrorKind.UniqueViolation(name)) => Assert.assertTrue(
                String.endsWith({suffix = "t.k"}, name)
            )
            case _ => Assert.assertTrue(false)
        }

}
