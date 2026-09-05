mod Sql.TestSel {

    use Db.Value
    use Sql.Sel

    def pair(): Sel[(String, Int32)] =
        Sql.intoRow(name -> lap -> (name, lap))
            |> Sql.pipeline(Sql.text("driver_name"))
            |> Sql.pipeline(Sql.int("lap_number"))

    @Test
    def theClauseFollowsTheOrderTheReadingsWerePipedIn(): Unit \ Assert =
        Assert.assertTrue(Sql.toSql(Sql.clause(pair())) == ("SELECT driver_name, lap_number", Nil))

    @Test
    def aReadingTakesTheCellUnderItsOwnExpression(): Unit \ Assert =
        Assert.assertTrue(
            Sql.decode(pair(), Some("Will STEVENS") :: Some("7") :: Nil) == Ok(("Will STEVENS", 7))
        )

    /// A `Sel` piped into another contributes its columns where it sits.
    @Test
    def aReadingMadeOfReadingsIsFlat(): Unit \ Assert =
        let sel = Sql.intoRow(p -> flag -> (p, flag))
            |> Sql.pipeline(pair())
            |> Sql.pipeline(Sql.text("flag_at_fl"));
        Assert.assertTrue(Sql.toSql(Sql.clause(sel)) == ("SELECT driver_name, lap_number, flag_at_fl", Nil));
        Assert.assertTrue(
            Sql.decode(sel, Some("Will STEVENS") :: Some("7") :: Some("SF") :: Nil)
                == Ok((("Will STEVENS", 7), "SF"))
        )

    @Test
    def aNullUnderANonOptionalReadingNamesTheExpression(): Unit \ Assert =
        Assert.assertTrue(
            Sql.decode(pair(), Some("Will STEVENS") :: None :: Nil)
                == Err("column `lap_number` was null")
        )

    @Test
    def aCellThatIsNotANumberNamesTheExpression(): Unit \ Assert =
        Assert.assertTrue(
            Sql.decode(pair(), Some("Will STEVENS") :: Some("7.5") :: Nil)
                == Err("column `lap_number` is not a number: \"7.5\"")
        )

    @Test
    def anOptionalReadingTakesANullAsNothing(): Unit \ Assert =
        let sel = Sql.optionalInt("pit_time_ms");
        Assert.assertTrue(Sql.decode(sel, None :: Nil) == Ok(None));
        Assert.assertTrue(Sql.decode(sel, Some("31000") :: Nil) == Ok(Some(31000)))

    @Test
    def anArrayReadingKeepsTheBlanksInPlace(): Unit \ Assert =
        let sel = Sql.optionalIntArray("mini_sector_time_ms");
        Assert.assertTrue(
            Sql.decode(sel, Some("[20708,null]") :: Nil) == Ok(Some(Some(20708) :: None :: Nil))
        );
        Assert.assertTrue(Sql.decode(sel, Some("[]") :: Nil) == Ok(Some(Nil)))

    @Test
    def aBooleanIsTheOneOrZeroTheDriverBoundIt(): Unit \ Assert =
        let sel = Sql.bool("crossing_finish_line_in_pit");
        Assert.assertTrue(Sql.decode(sel, Some("1") :: Nil) == Ok(true));
        Assert.assertTrue(Sql.decode(sel, Some("0") :: Nil) == Ok(false));
        Assert.assertTrue(
            Sql.decode(sel, Some("true") :: Nil)
                == Err("column `crossing_finish_line_in_pit` is not a boolean: \"true\"")
        )

    @Test
    def andThenReadsAReadingFurther(): Unit \ Assert =
        let sel = Sql.int("k") |> Sql.andThen(label ->
            if (label == 0) Ok("fastest lap") else Err("no record is labelled ${label}"));
        Assert.assertTrue(Sql.toSql(Sql.clause(sel)) == ("SELECT k", Nil));
        Assert.assertTrue(Sql.decode(sel, Some("0") :: Nil) == Ok("fastest lap"));
        Assert.assertTrue(Sql.decode(sel, Some("9") :: Nil) == Err("no record is labelled 9"))

    @Test
    def aRowLongerThanTheProjectionIsAnError(): Unit \ Assert =
        Assert.assertTrue(
            Sql.decode(pair(), Some("Will STEVENS") :: Some("7") :: Some("SF") :: Nil)
                == Err("the row carries 1 more columns than the projection reads")
        )

    @Test
    def aRowShorterThanTheProjectionNamesWhereItEnded(): Unit \ Assert =
        Assert.assertTrue(
            Sql.decode(pair(), Some("Will STEVENS") :: Nil) == Err("the row ended before `lap_number`")
        )

    ///
    /// ===== FRAGMENTS =====
    ///

    @Test
    def concatenatingPiecesCarriesTheirValuesInOrder(): Unit \ Assert =
        let frag = Sql.frags(
            Sql.raw("FROM laps WHERE") ::
            Sql.frag("season = ? AND round = ?", Value.Integer(2025) :: Value.Text("fuji_6h") :: Nil) ::
            Sql.raw("AND lap_number = ?") ::
            Sql.frag("", Value.Integer(1) :: Nil) :: Nil
        );
        Assert.assertTrue(Sql.toSql(frag) == (
            "FROM laps WHERE season = ? AND round = ? AND lap_number = ?",
            Value.Integer(2025) :: Value.Text("fuji_6h") :: Value.Integer(1) :: Nil
        ))

    /// The clause is rendered before the rest of the query, so a projection
    /// binding values of its own binds them first.
    @Test
    def theClausesValuesComeBeforeTheRests(): Unit \ Assert =
        let sel = Sql.optionalIntOf(Sql.frag("(SELECT off FROM b WHERE k = ?)", Value.Integer(7) :: Nil));
        let statement = Sql.statement(
            Sql.raw(""),
            Sql.frag("FROM laps WHERE season = ?", Value.Integer(2025) :: Nil),
            sel
        );
        Assert.assertTrue(Sql.toSql(statement) == (
            "SELECT (SELECT off FROM b WHERE k = ?) FROM laps WHERE season = ?",
            Value.Integer(7) :: Value.Integer(2025) :: Nil
        ))

}
