mod Db.TestJdbc {

    use Db.Laps

    use Db.Value

    import java.io.File

    use Db.Jdbc
    use Db.LapRow
    use Db.TestLapRow
    use Motorsport.Calendar.Entry
    use Round.TestSupport

    def connected(f: Unit -> Result[Db.Error, a] \ ef): Result[Db.Error, a] \ (ef - {SqlRead, SqlWrite, DbErr}) + IO =
        match Db.runWithError(() -> Jdbc.withConnection(TestSupport.url(), f)) {
            case Ok(result) => result
            case Err(e)     => Err(e)
        }

    @Test
    def aFetchReadsBackTextAndNulls(): Unit \ {Assert, IO} =
        let result = connected(() -> SqlRead.fetch("select 'a', null, 42, null", Nil));
        Assert.assertTrue(result == Ok((Some("a") :: None :: Some("42") :: None :: Nil) :: Nil))

    /// The driver's codes, read without a database: the extended ones carry
    /// the primary code in their low byte, so `SQLITE_BUSY_SNAPSHOT` is a
    /// lock like `SQLITE_BUSY` is.
    @Test
    def aLockIsTheOneRefusalThatSaysTryAgain(): Unit \ Assert =
        Assert.assertTrue(Jdbc.classify(5, "locked") == Db.Error.Busy("locked"));
        Assert.assertTrue(Jdbc.classify(6, "locked") == Db.Error.Busy("locked"));
        Assert.assertTrue(Jdbc.classify(517, "locked") == Db.Error.Busy("locked"));
        Assert.assertTrue(Jdbc.classify(1, "no such table: laps") == Db.Error.Refused("no such table: laps"));
        Assert.assertTrue(Jdbc.classify(1555, "constraint") == Db.Error.Refused("constraint"))

    /// What `Db.atomically` marks is SQLite's own savepoint, so this is where
    /// it is driven against one: a round of a load sends rows to several
    /// tables, and a failure at the last of them has to leave none of the
    /// others behind. `Db.Jdbc`'s savepoint is the insert's alone and would
    /// keep them.
    @Test
    def aFailedRoundLeavesNoneOfItsRowsBehind(): Unit \ {Assert, IO} =
        let refused = Db.Error.Incomplete("the round was not what it should have been");
        let counted = connected(() -> {
            discard Db.runWithError(() -> {
                Db.execute("CREATE TABLE t (n int not null)");
                Db.execute("INSERT INTO t VALUES (1)")
            });
            discard (Db.runWithError(() -> Db.atomically("round", () -> {
                Db.execute("INSERT INTO t VALUES (2)");
                Db.execute("INSERT INTO t VALUES (3)");
                DbErr.fail(refused)
            })): Result[Db.Error, Unit]);
            discard Db.runWithError(() -> Db.atomically("round", () ->
                Db.execute("INSERT INTO t VALUES (4)")));
            SqlRead.fetch("SELECT n FROM t ORDER BY n", Nil)
        });
        Assert.assertTrue(counted == Ok((Some("1") :: Nil) :: (Some("4") :: Nil) :: Nil))

    /// SQLite builds an index for a primary key unless the key is the row's
    /// own id, which it is only where the column is declared `integer`. The
    /// tables that number a name are read through that id, so an index over it
    /// would be the rows a second time; the ones keyed by more than a number
    /// say `WITHOUT ROWID` instead and are their key's tree outright.
    ///
    /// Neither is a thing the DDL says, so it is asked of a database that took
    /// it. What either would leave behind is an autoindex named for the table.
    @Test
    def aPrimaryKeyBuildsNoIndexOfItsOwn(): Unit \ {Assert, IO} =
        let indexes = table -> connected(() -> {
            discard Db.runWithError(() -> Db.execute(table));
            SqlRead.fetch(
                "SELECT name FROM sqlite_master WHERE type = 'index'"
                    + " AND name LIKE 'sqlite_autoindex%' ORDER BY name", Nil)
        });
        Assert.assertTrue(indexes(Db.Rounds.createTable()) == Ok(
            (Some("sqlite_autoindex_rounds_1") :: Nil) :: Nil
        ));
        Assert.assertTrue(indexes(Db.Drivers.createTable()) == Ok(
            (Some("sqlite_autoindex_drivers_1") :: Nil) :: Nil
        ));
        Assert.assertTrue(indexes(Db.CarDrivers.createTable()) == Ok(Nil));
        Assert.assertTrue(indexes(Db.Cars.createTable()) == Ok(Nil));
        Assert.assertTrue(indexes(Db.TimelineEvents.createTable()) == Ok(Nil))

    /// The connection the server answers through.
    @Test
    def aReadingConnectionAnswersAFetch(): Unit \ {Assert, IO} =
        let result = match Jdbc.connect(TestSupport.url()) {
            case Err(e)   => Err(e)
            case Ok(conn) =>
                let value = Jdbc.runReading(conn, () -> SqlRead.fetch("select 1", Nil));
                Jdbc.close(conn);
                value
        };
        Assert.assertTrue(result == Ok((Some("1") :: Nil) :: Nil))

    @Test
    def aFetchReadsEveryRowInTheOrderAsked(): Unit \ {Assert, IO} =
        let result = connected(() -> SqlRead.fetch(
            "select n from (select 1 as n union select 2 union select 3) order by n desc", Nil));
        Assert.assertTrue(result == Ok(
            (Some("3") :: Nil) :: (Some("2") :: Nil) :: (Some("1") :: Nil) :: Nil
        ))

    /// A value reaches the database as a binding rather than as text, so a
    /// round named with a quote in it is read rather than reported as a syntax
    /// error.
    @Test
    def aFetchBindsItsParameters(): Unit \ {Assert, IO} =
        let result = connected(() -> SqlRead.fetch(
            "select ?, ?", Value.Text("o'brien") :: Value.Integer(42) :: Nil));
        Assert.assertTrue(result == Ok((Some("o'brien") :: Some("42") :: Nil) :: Nil))

    /// The load of a round is one statement, so a database that refuses it
    /// leaves none of the round's rows behind rather than some of them.
    @Test
    def aRefusedLoadLeavesWhatWasThereAlone(): Unit \ {Assert, IO} =
        let rows = LapRow.fromRawLaps(1, TestLapRow.sampleLap() :: Nil);
        let outcome = connected(() -> {
            let accepted = Db.runWithError(() -> { Laps.create(); Laps.insertRows(rows) });
            let refused  = Db.runWithError(() -> Laps.insertRows(rows));
            let counted  = SqlRead.fetch("SELECT COUNT(*) FROM laps", Nil);
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
        let result = connected(() -> SqlRead.fetch("select 1 where 0", Nil));
        Assert.assertTrue(result == Ok(Nil))

    // --------------------------------------------------------- a file database

    /// The tests above connect to an in-memory database, which is neither
    /// created on a path nor journalled. What a run computes in is a file, so
    /// the two things `connect` does to reach one are driven here.

    /// A database of its own per test, under a directory that does not exist,
    /// which is what a working copy's `.db` is on a first run.
    def onFile(f: Unit -> Result[Db.Error, a] \ ef): (String, Result[Db.Error, a]) \ (ef - {SqlRead, SqlWrite, DbErr}) + IO =
        let stem = File.createTempFile("motorsport-test", "");
        discard stem.delete();
        let path = "${stem.getPath()}/motorsport.sqlite";
        let result = match Db.runWithError(() -> Jdbc.withConnection("jdbc:sqlite:${path}", f)) {
            case Ok(value) => value
            case Err(e)    => Err(e)
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
        let (path, result) = onFile(() -> SqlRead.fetch("select 1", Nil));
        Assert.assertTrue(result == Ok((Some("1") :: Nil) :: Nil));
        Assert.assertTrue(new File(path).exists());
        remove(path)

    /// The server answers on a pool and connects per request, so a read has to
    /// run beside a writing run rather than behind it.
    @Test
    def aFileDatabaseIsJournalledForConcurrentReaders(): Unit \ {Assert, IO} =
        let (path, result) = onFile(() -> SqlRead.fetch("PRAGMA journal_mode", Nil));
        Assert.assertTrue(result == Ok((Some("wal") :: Nil) :: Nil));
        remove(path)

    /// Two connections at once, which an in-memory database cannot be: each
    /// connection to one is a database of its own.
    @Test
    def aSecondConnectionReadsWhatTheFirstCommitted(): Unit \ {Assert, IO} =
        let (path, written) = onFile(() -> Db.runWithError(() -> Db.transact(load)));
        let readBack = counted(path);
        Assert.assertTrue(written == Ok(1));
        Assert.assertTrue(readBack == Ok((Some("1") :: Nil) :: Nil));
        remove(path)

    /// What a run that stopped partway left is what it started from: the
    /// `DROP TABLE` a rebuild opens with is undone with the rows it did not
    /// finish loading, so the table is not there to be read at all.
    @Test
    def whatWasNotCommittedIsNotThere(): Unit \ {Assert, IO} =
        let (path, written) = onFile(() -> Db.runWithError(() -> discard load()));
        Assert.assertTrue(written == Ok(()));
        match counted(path) {
            case Ok(_)  => Assert.assertTrue(false)
            case Err(_) => Assert.assertTrue(true)
        };
        remove(path)

    /// A transaction that answers with an error takes back what it sent.
    @Test
    def aTransactionThatFailedTakesBackWhatItSent(): Unit \ {Assert, IO} =
        let (path, written) = onFile(() -> Db.runWithError(() -> Db.transact(refuse)));
        Assert.assertTrue(written == Err(Db.Error.Incomplete("the round was not what it should have been")));
        match counted(path) {
            case Ok(_)  => Assert.assertTrue(false)
            case Err(_) => Assert.assertTrue(true)
        };
        remove(path)

    /// A round loaded and then judged unfit, which is a transaction answering
    /// with an error.
    def refuse(): Int32 \ DbWrite =
        discard load();
        DbErr.fail(Db.Error.Incomplete("the round was not what it should have been"))

    def load(): Int32 \ DbWrite =
        Laps.create();
        Laps.insertRows(LapRow.fromRawLaps(1, TestLapRow.sampleLap() :: Nil))

    /// From a connection of its own, so what it counts is what was committed.
    def counted(path: String): Result[Db.Error, List[List[Option[String]]]] \ IO =
        match Jdbc.connect("jdbc:sqlite:${path}") {
            case Err(e)   => Err(e)
            case Ok(conn) =>
                let value = Jdbc.runWith(conn, () -> SqlRead.fetch("SELECT COUNT(*) FROM laps", Nil));
                Jdbc.close(conn);
                value
        }

}
