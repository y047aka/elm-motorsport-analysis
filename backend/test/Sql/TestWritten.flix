/// A statement written out: where a named hole's piece lands, and the order the
/// values the statement cannot write for itself come out in.
pub mod Sql.TestWritten {

    use Lite3fx.DbErr
    use Lite3fx.DbError
    use Lite3fx.DbError.DbErrorKind
    use Lite3fx.SqlValue

    /// The round's rows, as a statement that wrote its own `WHERE` puts them.
    def scoped(): Sql.Frag =
        Sql.frag("round_id = ?", SqlValue.Int32(3) :: Nil)

    /// The statement, and the values its holes bound -- or the sentence saying a
    /// name is missing from one side or the other.
    def rendered(statement: Unit -> Sql.Query[a] \ DbErr): Result[DbErrorKind, (String, List[SqlValue])] =
        DbError.runWithKind(statement) |> Result.map(Sql.toStatement >> Sql.toSql)

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
                SqlValue.Int32(3) :: SqlValue.Int32(900) :: Nil
            )))

    /// The clause is a piece of the statement like any other, so a column that binds
    /// a value of its own has it come out between the values either side of it rather
    /// than last.
    @Test
    def aColumnThatBindsAValueKeepsItsPlaceAmongTheValues(): Unit \ Assert =
        Assert.assertTrue(rendered(() -> Sql.statement(
            "SELECT %% FROM laps WHERE {{scope}}" :: Nil,
            Map#{ "scope" => scoped() },
            Sql.optionalIntOf(Sql.frag("(SELECT ? FROM rounds LIMIT 1)", SqlValue.Int32(7) :: Nil))))
            == Ok((
                "SELECT (SELECT ? FROM rounds LIMIT 1) FROM laps WHERE round_id = ?",
                SqlValue.Int32(7) :: SqlValue.Int32(3) :: Nil
            )))

    /// The name is what orders the values, not the order the map happens to be
    /// walked in.
    @Test
    def aHoleNamedLaterThanAnotherStillComesOutWhereItStands(): Unit \ Assert =
        Assert.assertTrue(
            DbError.runWithKind(() -> Sql.spliced(
                "(SELECT car_number FROM laps WHERE {{scope}} AND lap_number > {{lap}})" :: Nil,
                Map#{ "lap" => Sql.frag("?", SqlValue.Int32(2) :: Nil), "scope" => scoped() }))
                |> Result.map(Sql.toSql)
                == Ok((
                    "(SELECT car_number FROM laps WHERE round_id = ? AND lap_number > ?)",
                    SqlValue.Int32(3) :: SqlValue.Int32(2) :: Nil
                )))

    /// A `{{name}}` the caller left with nothing in it is a mistake in the statement:
    /// it says which name, rather than sending SQL that fails somewhere the reader
    /// will not recognise.
    @Test
    def aHoleWithNothingToPutInItNamesTheMissingOne(): Unit \ Assert =
        Assert.assertTrue(sentence(DbError.runWithKind(() -> Sql.statement(
            "SELECT %% FROM laps WHERE round_id = {{scope}} AND lap_number = {{lap}}" :: Nil,
            Map#{ "scope" => scoped() },
            Sql.int("lap_number"))))
            == "the statement names `{{lap}}` and gives nothing for it:"
                + " SELECT %% FROM laps WHERE round_id = {{scope}} AND lap_number = {{lap}}")

    /// The other half of the same mistake: a piece the statement never asks for would
    /// leave its values bound to nothing.
    @Test
    def aPieceTheStatementNeverNamesSaysSo(): Unit \ Assert =
        Assert.assertTrue(sentence(DbError.runWithKind(() -> Sql.statement(
            "SELECT %% FROM laps WHERE round_id = {{scope}}" :: Nil,
            Map#{ "scope" => scoped(), "season" => Sql.frag("?", SqlValue.Str("2025") :: Nil) },
            Sql.int("lap_number"))))
            == "the statement never names `{{season}}`:"
                + " SELECT %% FROM laps WHERE round_id = {{scope}}")

    @Test
    def aStatementWithNoPlaceForItsClauseNamesItself(): Unit \ Assert =
        Assert.assertTrue(sentence(DbError.runWithKind(() -> Sql.statement(
            "SELECT car_number FROM laps WHERE round_id = {{scope}}" :: Nil,
            Map#{ "scope" => scoped() },
            Sql.int("lap_number"))))
            == "the statement has no `%%` for its SELECT clause:"
                + " SELECT car_number FROM laps WHERE round_id = {{scope}}")

    @Test
    def aPieceWithAMissingHoleNamesTheMissingOne(): Unit \ Assert =
        Assert.assertTrue(sentence(DbError.runWithKind(() ->
            Sql.spliced("round_id = {{scope}} AND season = {{season}}" :: Nil,
                Map#{ "scope" => scoped() })))
            == "the piece names `{{season}}` and gives nothing for it:"
                + " round_id = {{scope}} AND season = {{season}}")

    /// A comment written at the end of a clause is the one mistake a written statement
    /// can make that no database reports. `spaced` puts the statement back onto one
    /// line, so the comment reaches the database still open, and what it deletes behind
    /// itself -- here the `ORDER BY`, and in another statement the predicate next to it
    /// -- leaves a statement that runs and answers with the wrong rows.
    @Test
    def aLineCommentIsRefusedRatherThanRunOntoTheStatement(): Unit \ Assert =
        Assert.assertTrue(sentence(DbError.runWithKind(() -> Sql.statement(
            "SELECT %% FROM laps WHERE {{scope}}" ::
            "-- the round's own rows" ::
            "ORDER BY elapsed_ms ASC" :: Nil,
            Map#{ "scope" => scoped() },
            (Sql.text("car_number"), Sql.int("elapsed_ms")))))
            == "the statement holds a `--`, and its lines are run together into one, so the comment"
                + " reaches the database still open and has commented out every clause behind"
                + " it: SELECT %% FROM laps WHERE {{scope}} -- the round's own rows ORDER BY elapsed_ms ASC")

    @Test
    def aLineCommentInAPieceIsRefusedToo(): Unit \ Assert =
        Assert.assertTrue(sentence(DbError.runWithKind(() ->
            Sql.spliced("round_id = ? -- the round" :: "AND lap_number > 3" :: Nil,
                Map#{ "unused" => scoped() })))
            == "the piece holds a `--`, and its lines are run together into one, so the comment"
                + " reaches the database still open and has commented out every clause behind"
                + " it: round_id = ? -- the round AND lap_number > 3")

    /// The guard is on the one spelling that cannot survive the run together. A block
    /// comment closes itself and costs nothing, which is what a written statement is to
    /// use instead.
    @Test
    def aBlockCommentSurvivesTheRunTogetherAndIsNotRefused(): Unit \ Assert =
        Assert.assertTrue(rendered(() -> Sql.statement(
            "SELECT %% FROM laps /* the round's own rows */ WHERE {{scope}}" :: Nil,
            Map#{ "scope" => scoped() },
            (Sql.text("car_number"), Sql.int("elapsed_ms"))))
            == Ok((
                "SELECT car_number, elapsed_ms FROM laps /* the round's own rows */ WHERE round_id = ?",
                SqlValue.Int32(3) :: Nil
            )))

    /// The sentence a statement with its holes wrong is reported by.
    def sentence(outcome: Result[DbErrorKind, a]): String =
        match outcome {
            case Err(DbErrorKind.Other(text)) => text
            case _                      => ""
        }

}
