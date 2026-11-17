/// A statement the database refuses is reported with the statement it was asked in.
///
/// The driver names what it could not resolve -- `no such column: led.held` -- and
/// never the SQL it was written into, which is the half a reader of a statement
/// written out needs.
pub mod Db.TestRefusal {

    use Db.Jdbc

    @Test
    def aRefusalCarriesTheStatementItWasAskedIn(): Unit \ Assert + IO =
        let outcome = Db.runWithError(() -> Jdbc.withConnection(Round.TestSupport.url(), () ->
            Db.fetch("SELECT nope FROM laps WHERE round_id = 1", Nil)
        ));
        match outcome {
            case Err(Db.Error.Refused(why)) => Assert.assertTrue(String.endsWith(
                {suffix = ": SELECT nope FROM laps WHERE round_id = 1"}, why
            ))
            case _ => Assert.assertTrue(false)
        }

}
