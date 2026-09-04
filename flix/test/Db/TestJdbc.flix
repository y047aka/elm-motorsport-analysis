mod Db.TestJdbc {

    use Db.Jdbc
    use Db.LapRow
    use Db.TestLapRow
    use Motorsport.Calendar.Entry
    use Round.TestSupport

    /// A run that reaches no database fails these rather than skipping them:
    /// the point of them is the half of the boundary no compiler sees.
    def connected(f: Unit -> Result[String, a] \ ef): Result[String, a] \ (ef - Db) + IO =
        match Jdbc.connect(TestSupport.url()) {
            case Err(e)   => Err(e)
            case Ok(conn) =>
                let result = Jdbc.runWith(conn, f);
                Jdbc.close(conn);
                result
        }

    @Test
    def aFetchReadsBackTextAndNulls(): Unit \ {Assert, IO} =
        let result = connected(() -> Db.fetch("select 'a', null, 42, null"));
        Assert.assertTrue(result == Ok((Some("a") :: None :: Some("42") :: None :: Nil) :: Nil))

    @Test
    def aFetchReadsEveryRowInTheOrderAsked(): Unit \ {Assert, IO} =
        let result = connected(() -> Db.fetch(
            "select n from (select 1 as n union select 2 union select 3) order by n desc"));
        Assert.assertTrue(result == Ok(
            (Some("3") :: Nil) :: (Some("2") :: Nil) :: (Some("1") :: Nil) :: Nil
        ))

    /// The load of a round is one statement, so a database that refuses it
    /// leaves none of the round's rows behind rather than some of them.
    @Test
    def aRefusedLoadLeavesWhatWasThereAlone(): Unit \ {Assert, IO} =
        let entry: Entry = { season = 2025, id = "test_refused", date = "2025-01-01" };
        let rows = LapRow.fromRawLaps(entry, TestLapRow.sampleLap() :: Nil);
        let outcome = connected(() -> {
            discard Db.prepare();
            let accepted = Db.insertLaps(rows);
            let refused  = Db.insertLaps(rows);
            let counted  = Db.fetch("SELECT COUNT(*) FROM laps");
            Ok((accepted, refused, counted))
        });
        match outcome {
            case Ok((accepted, refused, counted)) =>
                Assert.assertTrue(accepted == Ok(1));
                match refused {
                    case Ok(_)  => Assert.assertTrue(false)
                    case Err(_) => Assert.assertTrue(true)
                };
                Assert.assertTrue(counted == Ok((Some("1") :: Nil) :: Nil))
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def aFetchWithNoRowsIsEmptyRatherThanAnError(): Unit \ {Assert, IO} =
        let result = connected(() -> Db.fetch("select 1 where 0"));
        Assert.assertTrue(result == Ok(Nil))

}
