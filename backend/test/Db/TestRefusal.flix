/// A statement the database refuses is reported with the statement it was asked in.
///
/// The driver names what it could not resolve -- `no such column: led.held` -- and
/// never the SQL it was written into, which is the half a reader of a statement
/// written out needs.
pub mod Db.TestRefusal {

    use Lite3fx.DbError
    use Lite3fx.DbError.DbErrorKind
    use Lite3fx.Jdbc
    use Round.TestSupport

    @Test
    def aRefusalCarriesTheStatementItWasAskedIn(): Unit \ Assert + IO =
        let outcome = DbError.runWithKind(() -> Jdbc.withConnection(TestSupport.url(), () ->
            Lite3fx.Sql.fetch("SELECT nope FROM laps WHERE round_id = 1", Nil)
        ));
        match outcome {
            case Err(DbErrorKind.SchemaMismatch(why)) => Assert.assertTrue(String.endsWith(
                {suffix = ": SELECT nope FROM laps WHERE round_id = 1"}, why
            ))
            case _ => Assert.assertTrue(false)
        }

}
