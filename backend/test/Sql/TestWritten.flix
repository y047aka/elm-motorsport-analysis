/// A statement written out: where a named hole's piece lands, and the order the
/// values the statement cannot write for itself come out in.
pub mod Sql.TestWritten {

    use Db.Error
    use Db.Value

    /// The round's rows, as a statement that wrote its own `WHERE` puts them.
    def scoped(): Sql.Frag =
        Sql.frag("round_id = ?", Value.Integer(3) :: Nil)

    /// The statement, and the values its holes bound -- or the sentence saying a
    /// name is missing from one side or the other.
    def rendered(statement: Unit -> Sql.Query[a] \ DbErr): Result[Db.Error, (String, List[Value])] =
        Db.runWithError(statement) |> Result.map(Sql.toStatement >> Sql.toSql)

    @Test
    def theClauseIsRenderedFromTheProjectionAndLandsWhereTheMarkerStands(): Unit \ Assert =
        Assert.assertTrue(rendered(() -> Sql.statement(
            "WITH c AS (SELECT car_number, elapsed_ms FROM laps WHERE {{scope}})" ::
            "SELECT %% FROM c WHERE elapsed_ms > {{since}}" :: Nil,
            Map#{ "scope" => scoped(), "since" => Sql.term(Sql.i32(900)) },
            (Sql.text("car_number"), Sql.int("elapsed_ms"))))
            == Ok((
                "WITH c AS (SELECT car_number, elapsed_ms FROM laps WHERE round_id = ?)"
                    + " SELECT car_number, elapsed_ms FROM c WHERE elapsed_ms > ?",
                Value.Integer(3) :: Value.Integer(900) :: Nil
            )))

    /// The clause is a piece of the statement like any other, so a column that binds
    /// a value of its own has it come out between the values either side of it rather
    /// than last.
    @Test
    def aColumnThatBindsAValueKeepsItsPlaceAmongTheValues(): Unit \ Assert =
        Assert.assertTrue(rendered(() -> Sql.statement(
            "SELECT %% FROM laps WHERE {{scope}}" :: Nil,
            Map#{ "scope" => scoped() },
            Sql.optionalIntOf(Sql.frag("(SELECT ? FROM rounds LIMIT 1)", Value.Integer(7) :: Nil))))
            == Ok((
                "SELECT (SELECT ? FROM rounds LIMIT 1) FROM laps WHERE round_id = ?",
                Value.Integer(7) :: Value.Integer(3) :: Nil
            )))

    /// The name is what orders the values, not the order the map happens to be
    /// walked in.
    @Test
    def aHoleNamedLaterThanAnotherStillComesOutWhereItStands(): Unit \ Assert =
        Assert.assertTrue(
            Db.runWithError(() -> Sql.spliced(
                "(SELECT car_number FROM laps WHERE {{scope}} AND lap_number > {{lap}})" :: Nil,
                Map#{ "lap" => Sql.frag("?", Value.Integer(2) :: Nil), "scope" => scoped() }))
                |> Result.map(Sql.toSql)
                == Ok((
                    "(SELECT car_number FROM laps WHERE round_id = ? AND lap_number > ?)",
                    Value.Integer(3) :: Value.Integer(2) :: Nil
                )))

    /// A `{{name}}` the caller left with nothing in it is a mistake in the statement:
    /// it says which name, rather than sending SQL that fails somewhere the reader
    /// will not recognise.
    @Test
    def aHoleWithNothingToPutInItNamesTheMissingOne(): Unit \ Assert =
        Assert.assertTrue(sentence(Db.runWithError(() -> Sql.statement(
            "SELECT %% FROM laps WHERE round_id = {{scope}} AND lap_number = {{lap}}" :: Nil,
            Map#{ "scope" => scoped() },
            Sql.int("lap_number"))))
            == "the statement names `{{lap}}` and gives nothing for it:"
                + " SELECT %% FROM laps WHERE round_id = {{scope}} AND lap_number = {{lap}}")

    /// The other half of the same mistake: a piece the statement never asks for would
    /// leave its values bound to nothing.
    @Test
    def aPieceTheStatementNeverNamesSaysSo(): Unit \ Assert =
        Assert.assertTrue(sentence(Db.runWithError(() -> Sql.statement(
            "SELECT %% FROM laps WHERE round_id = {{scope}}" :: Nil,
            Map#{ "scope" => scoped(), "season" => Sql.frag("?", Value.Text("2025") :: Nil) },
            Sql.int("lap_number"))))
            == "the statement never names `{{season}}`:"
                + " SELECT %% FROM laps WHERE round_id = {{scope}}")

    @Test
    def aStatementWithNoPlaceForItsClauseNamesItself(): Unit \ Assert =
        Assert.assertTrue(sentence(Db.runWithError(() -> Sql.statement(
            "SELECT car_number FROM laps WHERE round_id = {{scope}}" :: Nil,
            Map#{ "scope" => scoped() },
            Sql.int("lap_number"))))
            == "the statement has no `%%` for its SELECT clause:"
                + " SELECT car_number FROM laps WHERE round_id = {{scope}}")

    @Test
    def aPieceWithAMissingHoleNamesTheMissingOne(): Unit \ Assert =
        Assert.assertTrue(sentence(Db.runWithError(() ->
            Sql.spliced("round_id = {{scope}} AND season = {{season}}" :: Nil,
                Map#{ "scope" => scoped() })))
            == "the piece names `{{season}}` and gives nothing for it:"
                + " round_id = {{scope}} AND season = {{season}}")

    /// The sentence a statement with its holes wrong is reported by.
    def sentence(outcome: Result[Db.Error, a]): String =
        match outcome {
            case Err(Error.Other(text)) => text
            case _                      => ""
        }

}
