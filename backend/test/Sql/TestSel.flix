pub mod Sql.TestSel {
    use Lite3fx.DbError.DbErrorKind
    use Lite3fx.SqlValue

    use Sql.Sel

    def pair(): Sel[(String, Int32)] =
        Sql.Project.sel((Sql.text("driver_name"), Sql.int("lap_number")))

    @Test
    def theClauseFollowsTheOrderTheProjectionNamesThem(): Unit \ Assert =
        Assert.assertTrue(Sql.toSql(Sql.clause(pair())) == ("SELECT driver_name, lap_number", Nil))

    @Test
    def aReadingTakesTheCellUnderItsOwnExpression(): Unit \ Assert =
        Assert.assertTrue(
            Sql.decode(pair(), TestCells.answering(pair(), Some("Will STEVENS") :: Some("7") :: Nil))
                == Ok(("Will STEVENS", 7))
        )

    /// A reading of several is itself a reading, and contributes its columns
    /// where it sits.
    @Test
    def aReadingMadeOfReadingsIsFlat(): Unit \ Assert =
        let sel = Sql.Project.sel((pair(), Sql.text("flag_at_fl")));
        Assert.assertTrue(Sql.toSql(Sql.clause(sel)) == ("SELECT driver_name, lap_number, flag_at_fl", Nil));
        Assert.assertTrue(
            Sql.decode(sel, TestCells.answering(sel, Some("Will STEVENS") :: Some("7") :: Some("SF") :: Nil))
                == Ok((("Will STEVENS", 7), "SF"))
        )

    @Test
    def aNullUnderANonOptionalReadingNamesTheExpression(): Unit \ Assert =
        Assert.assertTrue(
            Sql.decode(pair(), TestCells.answering(pair(), Some("Will STEVENS") :: None :: Nil))
                == Err(DbErrorKind.DecodeError("lap_number", "was null"))
        )

    @Test
    def aCellThatIsNotANumberNamesTheExpression(): Unit \ Assert =
        Assert.assertTrue(
            Sql.decode(pair(), TestCells.answering(pair(), Some("Will STEVENS") :: Some("7.5") :: Nil))
                == Err(DbErrorKind.DecodeError("lap_number", "is not a number: \"7.5\""))
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
                == Err(DbErrorKind.DecodeError("crossing_finish_line_in_pit", "is not a boolean: \"true\""))
        )

    @Test
    def andThenReadsAReadingFurther(): Unit \ Assert =
        let sel = Sql.int("k") |> Sql.andThen(label ->
            if (label == 0) Ok("fastest lap") else Err(DbErrorKind.Other("no record is labelled ${label}")));
        Assert.assertTrue(Sql.toSql(Sql.clause(sel)) == ("SELECT k", Nil));
        Assert.assertTrue(Sql.decode(sel, TestCells.answering(sel, Some("0") :: Nil)) == Ok("fastest lap"));
        Assert.assertTrue(
            Sql.decode(sel, TestCells.answering(sel, Some("9") :: Nil))
                == Err(DbErrorKind.Other("no record is labelled 9"))
        )

    /// The far side of a `LEFT JOIN`: a null cell is the row the join did not
    /// find rather than a reading that failed.
    @Test
    def aReadingOfTheFarSideOfAJoinTakesANullAsNothing(): Unit \ Assert =
        let sel = Sql.orNull(Sql.int("l1.elapsed_ms"));
        Assert.assertTrue(Sql.toSql(Sql.clause(sel)) == ("SELECT l1.elapsed_ms", Nil));
        Assert.assertTrue(Sql.decode(sel, TestCells.answering(sel, None :: Nil)) == Ok(None));
        Assert.assertTrue(Sql.decode(sel, TestCells.answering(sel, Some("95365") :: Nil)) == Ok(Some(95365)))

    /// It takes the cells its reading would have taken, whichever way it
    /// answers, so the readings beside it are still on their own.
    @Test
    def aReadingOfTheFarSideTakesItsOwnCellsEitherWay(): Unit \ Assert =
        let sel = Sql.Project.sel((Sql.orNull(Sql.int("l1.elapsed_ms")), Sql.text("c.car_number")));
        Assert.assertTrue(
            Sql.decode(sel, TestCells.answering(sel, None :: Some("12") :: Nil)) == Ok((None, "12"))
        );
        Assert.assertTrue(
            Sql.decode(sel, TestCells.answering(sel, Some("95365") :: Some("12") :: Nil)) == Ok((Some(95365), "12"))
        )

    @Test
    def aRowOfAnotherWidthNamesBothCounts(): Unit \ Assert =
        Assert.assertTrue(
            Sql.decode(pair(), TestCells.answering(pair(), Some("Will STEVENS") :: Some("7") :: Some("SF") :: Nil))
                == Err(DbErrorKind.SchemaMismatch("the projection names 2 columns and the row carries 3"))
        );
        Assert.assertTrue(
            Sql.decode(pair(), TestCells.answering(pair(), Some("Will STEVENS") :: Nil))
                == Err(DbErrorKind.SchemaMismatch("the projection names 2 columns and the row carries 1"))
        )

    /// A column renamed on one side of the two and not the other is the mistake
    /// the position would have hidden: it reads the cell beside the one it wanted
    /// and answers with it.
    @Test
    def aProjectionTheRowDoesNotAnswerNamesItself(): Unit \ Assert =
        Assert.assertTrue(
            Sql.decode(pair(), TestCells.row(
                "driver_name" :: "lap" :: Nil,
                Some("Will STEVENS") :: Some("7") :: Nil))
                == Err(DbErrorKind.SchemaMismatch("no column of the row answers to the projected `lap_number`"))
        )

    /// The row answers in whatever order the clause came back in, and the reading
    /// goes by the names rather than by how many cells precede each one.
    @Test
    def aRowAnsweringInAnotherOrderIsStillReadRight(): Unit \ Assert =
        Assert.assertTrue(
            Sql.decode(pair(), TestCells.row(
                "lap_number" :: "driver_name" :: Nil,
                Some("7") :: Some("Will STEVENS") :: Nil))
                == Ok(("Will STEVENS", 7))
        )

    /// A column named through its qualifier comes back under its own name, which
    /// is what the clause writes and what the reading looks for.
    @Test
    def aQualifiedColumnIsReadByItsOwnName(): Unit \ Assert =
        let sel = Sql.text("c.car_number");
        Assert.assertTrue(Sql.toSql(Sql.clause(sel)) == ("SELECT c.car_number", Nil));
        Assert.assertTrue(
            Sql.decode(sel, TestCells.row("car_number" :: Nil, Some("51") :: Nil)) == Ok("51")
        )

    /// An `AS` names the column the reading answers to, and the row answers under
    /// that name and not under the expression.
    @Test
    def anAliasedProjectionIsReadByItsAlias(): Unit \ Assert =
        let sel = Sql.optionalIntArray("json_array(1, 2) AS mini_best");
        Assert.assertTrue(
            Sql.decode(sel, TestCells.row("mini_best" :: Nil, Some("[20708,null]") :: Nil))
                == Ok(Some(Some(20708) :: None :: Nil))
        )

    /// A join naming both sides' `elapsed_ms` has two columns under one label,
    /// which the order the clause writes them answers.
    @Test
    def twoProjectionsUnderOneLabelAreAnsweredInOrder(): Unit \ Assert =
        let sel = Sql.Project.sel((Sql.int("l1.elapsed_ms"), Sql.int("l2.elapsed_ms")));
        Assert.assertTrue(Sql.toSql(Sql.clause(sel)) == ("SELECT l1.elapsed_ms, l2.elapsed_ms", Nil));
        Assert.assertTrue(
            Sql.decode(sel, TestCells.row(
                "elapsed_ms" :: "elapsed_ms" :: Nil,
                Some("95365") :: Some("102813") :: Nil))
                == Ok((95365, 102813))
        )

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

    /// The clause is rendered before the rest of the query, so a projection
    /// binding values of its own binds them first.
    @Test
    def theClausesValuesComeBeforeTheRests(): Unit \ Assert =
        let statement = Sql.rows(Sql.raw("laps"))
            |> Sql.filter(_ -> Sql.eq(Sql.column("season"), Sql.i32(2025)))
            |> Sql.map(_ -> Sql.optionalIntOf(
                Sql.frag("(SELECT off FROM b WHERE k = ?)", SqlValue.Int32(7) :: Nil)))
            |> Sql.toStatement;
        Assert.assertTrue(Sql.toSql(statement) == (
            "SELECT (SELECT off FROM b WHERE k = ?) FROM laps WHERE season = ?",
            SqlValue.Int32(7) :: SqlValue.Int32(2025) :: Nil
        ))

}
