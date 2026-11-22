pub mod Sql.TestSel {
    use Sqlitefx.DbError.DbErrorKind
    use Sqlitefx.Decoder.Decoder
    use Sqlitefx.SqlValue

    def pair(): Decoder[(String, Int32)] =
        Sql.Project.decoder((Sql.text("driver_name"), Sql.int("lap_number")))

    @Test
    def theClauseFollowsTheOrderTheProjectionNamesThem(): Unit \ Assert =
        Assert.assertTrue(Sql.toSql(Sql.clause(pair())) == ("SELECT driver_name, lap_number", Nil))

    @Test
    def aReadingTakesTheCellUnderItsOwnLabel(): Unit \ Assert =
        Assert.assertTrue(
            Sql.decode(pair(), TestCells.answering(pair(), Some("Will STEVENS") :: Some("7") :: Nil))
                == Ok(("Will STEVENS", 7))
        )

    /// A reading of several is itself a reading, and contributes its columns
    /// where it sits.
    @Test
    def aReadingMadeOfReadingsIsFlat(): Unit \ Assert =
        let sel = Sql.Project.decoder((pair(), Sql.text("flag_at_fl")));
        Assert.assertTrue(Sql.toSql(Sql.clause(sel)) == ("SELECT driver_name, lap_number, flag_at_fl", Nil));
        Assert.assertTrue(
            Sql.decode(sel, TestCells.answering(sel, Some("Will STEVENS") :: Some("7") :: Some("SF") :: Nil))
                == Ok((("Will STEVENS", 7), "SF"))
        )

    @Test
    def aNullUnderANonOptionalReadingNamesTheLabel(): Unit \ Assert =
        Assert.assertTrue(
            Sql.decode(pair(), TestCells.answering(pair(), Some("Will STEVENS") :: None :: Nil))
                == Err(DbErrorKind.DecodeError("lap_number", "column 'lap_number' is NULL"))
        )

    @Test
    def aCellThatIsNotANumberNamesTheLabel(): Unit \ Assert =
        Assert.assertTrue(
            Sql.decode(pair(), TestCells.answering(pair(), Some("Will STEVENS") :: Some("7.5") :: Nil))
                == Err(DbErrorKind.DecodeError("lap_number", "column 'lap_number' is Str, expected an integer"))
        )

    @Test
    def anOptionalReadingTakesANullAsNothing(): Unit \ Assert =
        let sel = Sql.optionalInt("pit_time_ms");
        Assert.assertTrue(Sql.decode(sel, TestCells.answering(sel, None :: Nil)) == Ok(None));
        Assert.assertTrue(Sql.decode(sel, TestCells.answering(sel, Some("31000") :: Nil)) == Ok(Some(31000)))

    @Test
    def anArrayReadingKeepsTheBlanksInPlace(): Unit \ Assert =
        let sel = Sql.optionalIntArray("mini_sector_time_ms");
        Assert.assertTrue(
            Sql.decode(sel, TestCells.answering(sel, Some("[20708,null]") :: Nil))
                == Ok(Some(Some(20708) :: None :: Nil))
        );
        Assert.assertTrue(Sql.decode(sel, TestCells.answering(sel, Some("[]") :: Nil)) == Ok(Some(Nil)))

    @Test
    def aBooleanIsTheOneOrZeroTheDriverBoundIt(): Unit \ Assert =
        let sel = Sql.bool("crossing_finish_line_in_pit");
        Assert.assertTrue(Sql.decode(sel, TestCells.answering(sel, Some("1") :: Nil)) == Ok(true));
        Assert.assertTrue(Sql.decode(sel, TestCells.answering(sel, Some("0") :: Nil)) == Ok(false));
        Assert.assertTrue(
            Sql.decode(sel, TestCells.answering(sel, Some("true") :: Nil))
                == Err(DbErrorKind.DecodeError("crossing_finish_line_in_pit", "column 'crossing_finish_line_in_pit' is Str, expected 1 or 0"))
        )

    @Test
    def refineReadsAReadingFurther(): Unit \ Assert =
        let sel = Sql.int("k") |> Sql.refine("a record's label", label ->
            if (label == 0) Some("fastest lap") else None);
        Assert.assertTrue(Sql.toSql(Sql.clause(sel)) == ("SELECT k", Nil));
        Assert.assertTrue(Sql.decode(sel, TestCells.answering(sel, Some("0") :: Nil)) == Ok("fastest lap"));
        Assert.assertTrue(
            Sql.decode(sel, TestCells.answering(sel, Some("9") :: Nil))
                == Err(DbErrorKind.DecodeError("k", "column 'k' is 9, expected a record's label"))
        )

    /// The far side of a `LEFT JOIN`: a null cell is the row the join did not
    /// find rather than a reading that failed.
    @Test
    def aReadingOfTheFarSideOfAJoinTakesANullAsNothing(): Unit \ Assert =
        let sel = Sql.orNull(Sql.int("l1.elapsed_ms"));
        Assert.assertTrue(Sql.toSql(Sql.clause(sel)) == ("SELECT l1.elapsed_ms AS l1_elapsed_ms", Nil));
        Assert.assertTrue(Sql.decode(sel, TestCells.answering(sel, None :: Nil)) == Ok(None));
        Assert.assertTrue(Sql.decode(sel, TestCells.answering(sel, Some("95365") :: Nil)) == Ok(Some(95365)))

    /// A projection the row does not answer is refused by its label, rather than reading the cell beside the one it wanted.
    @Test
    def aProjectionTheRowDoesNotAnswerNamesItself(): Unit \ Assert =
        Assert.assertTrue(
            Sql.decode(pair(), TestCells.row(
                "driver_name" :: "lap" :: Nil,
                Some("Will STEVENS") :: Some("7") :: Nil))
                == Err(DbErrorKind.DecodeError("lap_number", "column 'lap_number' is missing"))
        )

    /// The row answers in whatever order the clause came back in, and the reading goes by the labels.
    @Test
    def aRowAnsweringInAnotherOrderIsStillReadRight(): Unit \ Assert =
        Assert.assertTrue(
            Sql.decode(pair(), TestCells.row(
                "lap_number" :: "driver_name" :: Nil,
                Some("7") :: Some("Will STEVENS") :: Nil))
                == Ok(("Will STEVENS", 7))
        )

    /// A column named through its qualifier is given a label of its own, so the two sides of a join are two labels.
    @Test
    def aQualifiedColumnIsReadUnderALabelOfItsOwn(): Unit \ Assert =
        let sel = Sql.Project.decoder((Sql.int("l1.elapsed_ms"), Sql.int("l2.elapsed_ms")));
        Assert.assertTrue(Sql.toSql(Sql.clause(sel)) == (
            "SELECT l1.elapsed_ms AS l1_elapsed_ms, l2.elapsed_ms AS l2_elapsed_ms", Nil));
        Assert.assertTrue(
            Sql.decode(sel, TestCells.answering(sel, Some("95365") :: Some("102813") :: Nil))
                == Ok((95365, 102813))
        )

    /// A label the caller gives is the one the clause writes and the reading looks for.
    @Test
    def aLabelledProjectionIsReadByItsLabel(): Unit \ Assert =
        let sel = Sql.labelled("mini_best", Sql.optionalIntArray("json_array(1, 2)"));
        Assert.assertTrue(Sql.toSql(Sql.clause(sel)) == ("SELECT json_array(1, 2) AS mini_best", Nil));
        Assert.assertTrue(
            Sql.decode(sel, TestCells.row("mini_best" :: Nil, Some("[20708,null]") :: Nil))
                == Ok(Some(Some(20708) :: None :: Nil))
        )

    /// An expression that is not a name is labelled from its text.
    @Test
    def anExpressionIsLabelledFromItsText(): Unit \ Assert =
        Assert.assertTrue(Sql.toSql(Sql.clause(Sql.int("m.key + 1"))) == ("SELECT m.key + 1 AS m_key_1", Nil))

    ///
    /// ===== FRAGMENTS =====
    ///

    @Test
    def concatenatingPiecesCarriesTheirValuesInOrder(): Unit \ Assert =
        let frag = Sql.frags(
            Sql.raw("FROM laps WHERE") ::
            Sql.frag("season = ? AND round = ?", SqlValue.Int32(2025) :: SqlValue.Str("fuji_6h") :: Nil) ::
            Sql.raw("AND lap_number = ?") ::
            Sql.frag("", SqlValue.Int32(1) :: Nil) :: Nil
        );
        Assert.assertTrue(Sql.toSql(frag) == (
            "FROM laps WHERE season = ? AND round = ? AND lap_number = ?",
            SqlValue.Int32(2025) :: SqlValue.Str("fuji_6h") :: SqlValue.Int32(1) :: Nil
        ))

}
