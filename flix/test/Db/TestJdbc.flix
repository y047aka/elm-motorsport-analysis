mod Db.TestJdbc {

    use Db.Laps

    use Db.Value

    import java.io.File

    use Db.Jdbc
    use Db.LapRow
    use Db.TestLapRow
    use Motorsport.Calendar.Entry
    use Round.TestSupport

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
        let result = connected(() -> Db.fetch("select 'a', null, 42, null", Nil));
        Assert.assertTrue(result == Ok((Some("a") :: None :: Some("42") :: None :: Nil) :: Nil))

    @Test
    def aFetchReadsEveryRowInTheOrderAsked(): Unit \ {Assert, IO} =
        let result = connected(() -> Db.fetch(
            "select n from (select 1 as n union select 2 union select 3) order by n desc", Nil));
        Assert.assertTrue(result == Ok(
            (Some("3") :: Nil) :: (Some("2") :: Nil) :: (Some("1") :: Nil) :: Nil
        ))

    /// A value reaches the database as a binding rather than as text, so a
    /// round named with a quote in it is read rather than reported as a syntax
    /// error.
    @Test
    def aFetchBindsItsParameters(): Unit \ {Assert, IO} =
        let result = connected(() -> Db.fetch(
            "select ?, ?", Value.Text("o'brien") :: Value.Integer(42) :: Nil));
        Assert.assertTrue(result == Ok((Some("o'brien") :: Some("42") :: Nil) :: Nil))

    /// The load of a round is one statement, so a database that refuses it
    /// leaves none of the round's rows behind rather than some of them.
    @Test
    def aRefusedLoadLeavesWhatWasThereAlone(): Unit \ {Assert, IO} =
        let entry: Entry = { season = 2025, id = "test_refused", date = "2025-01-01" };
        let rows = LapRow.fromRawLaps(entry, TestLapRow.sampleLap() :: Nil);
        let outcome = connected(() -> {
            discard Laps.create();
            let accepted = Laps.insertRows(rows);
            let refused  = Laps.insertRows(rows);
            let counted  = Db.fetch("SELECT COUNT(*) FROM laps", Nil);
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
        let result = connected(() -> Db.fetch("select 1 where 0", Nil));
        Assert.assertTrue(result == Ok(Nil))

    // --------------------------------------------------------- a file database

    /// The tests above connect to an in-memory database, which is neither
    /// created on a path nor journalled. What a run computes in is a file, so
    /// the two things `connect` does to reach one are driven here.

    /// A database of its own per test, under a directory that does not exist,
    /// which is what a working copy's `.db` is on a first run.
    def onFile(f: Unit -> Result[String, a] \ ef): (String, Result[String, a]) \ (ef - Db) + IO =
        let stem = File.createTempFile("motorsport-test", "");
        discard stem.delete();
        let path = "${stem.getPath()}/motorsport.sqlite";
        let result = match Jdbc.connect("jdbc:sqlite:${path}") {
            case Err(e)   => Err(e)
            case Ok(conn) =>
                let value = Jdbc.runWith(conn, f);
                Jdbc.close(conn);
                value
        };
        (path, result)

    def remove(path: String): Unit \ IO =
        let file = new File(path);
        discard file.delete();
        match Object.toOption(file.getParentFile()) {
            case Some(parent) => discard parent.delete()
            case None         => ()
        }

    /// SQLite creates the file and not the directory holding it, so a URL
    /// naming one that does not exist reaches no database at all.
    @Test
    def connectingMakesTheDirectoryTheFileNeeds(): Unit \ {Assert, IO} =
        let (path, result) = onFile(() -> Db.fetch("select 1", Nil));
        Assert.assertTrue(result == Ok((Some("1") :: Nil) :: Nil));
        Assert.assertTrue(new File(path).exists());
        remove(path)

    /// The server answers on a pool and connects per request, so a read has to
    /// run beside a writing run rather than behind it.
    @Test
    def aFileDatabaseIsJournalledForConcurrentReaders(): Unit \ {Assert, IO} =
        let (path, result) = onFile(() -> Db.fetch("PRAGMA journal_mode", Nil));
        Assert.assertTrue(result == Ok((Some("wal") :: Nil) :: Nil));
        remove(path)

    /// Two connections at once, which an in-memory database cannot be: each
    /// connection to one is a database of its own.
    @Test
    def aSecondConnectionReadsWhatTheFirstCommitted(): Unit \ {Assert, IO} =
        let (path, written) = onFile(() -> Db.transact(() -> load()));
        let readBack = counted(path);
        Assert.assertTrue(written == Ok(1));
        Assert.assertTrue(readBack == Ok((Some("1") :: Nil) :: Nil));
        remove(path)

    /// What a run that stopped partway left is what it started from: the
    /// `DROP TABLE` a rebuild opens with is undone with the rows it did not
    /// finish loading, so the table is not there to be read at all.
    @Test
    def whatWasNotCommittedIsNotThere(): Unit \ {Assert, IO} =
        let (path, written) = onFile(() -> {
            discard load();
            Ok(())
        });
        Assert.assertTrue(written == Ok(()));
        match counted(path) {
            case Ok(_)  => Assert.assertTrue(false)
            case Err(_) => Assert.assertTrue(true)
        };
        remove(path)

    /// A transaction that answers with an error takes back what it sent.
    @Test
    def aTransactionThatFailedTakesBackWhatItSent(): Unit \ {Assert, IO} =
        let (path, written) = onFile(() -> Db.transact(refuse));
        Assert.assertTrue(written == Err("the round was not what it should have been"));
        match counted(path) {
            case Ok(_)  => Assert.assertTrue(false)
            case Err(_) => Assert.assertTrue(true)
        };
        remove(path)

    /// A round loaded and then judged unfit, which is a transaction answering
    /// with an error.
    def refuse(): Result[String, Int32] \ Db =
        match load() {
            case Ok(_)  => Err("the round was not what it should have been")
            case Err(e) => Err(e)
        }

    def load(): Result[String, Int32] \ Db =
        let entry: Entry = { season = 2025, id = "test_shared", date = "2025-01-01" };
        forM(
            _        <- Laps.create();
            accepted <- Laps.insertRows(LapRow.fromRawLaps(entry, TestLapRow.sampleLap() :: Nil))
        ) yield accepted

    /// From a connection of its own, so what it counts is what was committed.
    def counted(path: String): Result[String, List[List[Option[String]]]] \ IO =
        match Jdbc.connect("jdbc:sqlite:${path}") {
            case Err(e)   => Err(e)
            case Ok(conn) =>
                let value = Jdbc.runWith(conn, () -> Db.fetch("SELECT COUNT(*) FROM laps", Nil));
                Jdbc.close(conn);
                value
        }

}
