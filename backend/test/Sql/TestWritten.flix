/// A statement written out: where the `SELECT` clause lands, and the order the
/// values the statement cannot write for itself come out in.
pub mod Sql.TestWritten {

    use Db.Error
    use Db.Value

    /// The round's rows, as a statement that wrote its own `WHERE` puts them.
    def scoped(): Sql.Frag =
        Sql.frag("round_id = ?", Value.Integer(3) :: Nil)

    /// The statement, and the values its holes bound -- or the sentence saying
    /// its markers and its pieces disagree.
    def rendered(statement: Unit -> Sql.Query[a] \ DbErr): Result[Db.Error, (String, List[Value])] =
        Db.runWithError(statement) |> Result.map(Sql.toStatement >> Sql.toSql)

    @Test
    def theClauseIsRenderedFromTheProjectionAndLandsWhereTheMarkerStands(): Unit \ Assert =
        Assert.assertTrue(rendered(() -> Sql.statement(
            "WITH c AS (SELECT car_number, elapsed_ms FROM laps WHERE ??)"
                + " SELECT %% FROM c WHERE elapsed_ms > ??",
            scoped() :: Sql.term(Sql.i32(900)) :: Nil,
            (Sql.text("car_number"), Sql.int("elapsed_ms"))))
            == Ok((
                "WITH c AS (SELECT car_number, elapsed_ms FROM laps WHERE round_id = ?)"
                    + " SELECT car_number, elapsed_ms FROM c WHERE elapsed_ms > ?",
                Value.Integer(3) :: Value.Integer(900) :: Nil
            )))

    /// The clause is a piece of the statement like any other, so a column that
    /// binds a value of its own has it come out between the values either side
    /// of it rather than last.
    @Test
    def aColumnThatBindsAValueKeepsItsPlaceAmongTheValues(): Unit \ Assert =
        Assert.assertTrue(rendered(() -> Sql.statement(
            "SELECT %% FROM laps WHERE ??",
            scoped() :: Nil,
            Sql.optionalIntOf(Sql.frag("(SELECT ? FROM rounds LIMIT 1)", Value.Integer(7) :: Nil))))
            == Ok((
                "SELECT (SELECT ? FROM rounds LIMIT 1) FROM laps WHERE round_id = ?",
                Value.Integer(7) :: Value.Integer(3) :: Nil
            )))

    @Test
    def aPieceOfAStatementTakesItsHolesInOrder(): Unit \ Assert =
        Assert.assertTrue(
            Db.runWithError(() -> Sql.spliced(
                "(SELECT car_number FROM laps WHERE ?? AND lap_number > ?)",
                scoped() :: Nil))
                |> Result.map(Sql.toSql)
                == Ok((
                    "(SELECT car_number FROM laps WHERE round_id = ? AND lap_number > ?)",
                    Value.Integer(3) :: Nil
                )))

    /// A `??` the caller left, or a piece left over, is a mistake in the
    /// statement: it says which statement, rather than sending SQL that fails
    /// somewhere the reader will not recognise.
    @Test
    def aHoleWithNothingToPutInItNamesTheStatement(): Unit \ Assert =
        Assert.assertTrue(sentence(Db.runWithError(() -> Sql.statement(
            "SELECT %% FROM laps WHERE round_id = ?? AND lap_number = ??",
            scoped() :: Nil,
            Sql.int("lap_number"))))
            == "the statement has 2 `??` and 1 to put in them:"
                + " SELECT %% FROM laps WHERE round_id = ?? AND lap_number = ??")

    @Test
    def aStatementWithNoPlaceForItsClauseNamesItself(): Unit \ Assert =
        Assert.assertTrue(sentence(Db.runWithError(() -> Sql.statement(
            "SELECT car_number FROM laps WHERE round_id = ??",
            scoped() :: Nil,
            Sql.int("lap_number"))))
            == "the statement has no `%%` for its SELECT clause:"
                + " SELECT car_number FROM laps WHERE round_id = ??")

    @Test
    def aPieceWithMoreHolesThanPiecesSaysSo(): Unit \ Assert =
        Assert.assertTrue(sentence(Db.runWithError(() ->
            Sql.spliced("round_id = ?? AND season = ??", scoped() :: Nil)))
            == "the piece has 2 `??` and 1 to put in them: round_id = ?? AND season = ??")

    /// The sentence a statement with its markers wrong is reported by.
    def sentence(outcome: Result[Db.Error, a]): String =
        match outcome {
            case Err(Error.Other(text)) => text
            case _                      => ""
        }

}
