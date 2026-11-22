/// The connection `Db.connection` configures, driven against SQLite itself: what the tables declare, what a round's savepoint takes back, and what a file database is opened as.
///
/// How the library binds, reads and refuses is `backend/sqlitefx`'s tests'.
pub mod Db.TestJdbc {
    use Sqlitefx.DbErr
    use Sqlitefx.DbError
    use Sqlitefx.DbError.DbErrorKind
    use Sqlitefx.DbWrite
    use Sqlitefx.Jdbc
    use Sqlitefx.RawSql
    use Sqlitefx.Row.Row
    use Sqlitefx.SqlValue
    use Sqlitefx.Tx

    use Db.Laps

    import java.io.File
    import java.sql.Connection

    use Db.LapRow
    use Db.TestLapRow
    use Round.TestSupport

    def cells(rows: Result[DbErrorKind, List[Row]]): Result[DbErrorKind, List[List[SqlValue]]] =
        Result.map(List.map(row -> Vector.toList(row#cells)), rows)

    def connectedTo(url: String, f: Connection -> a \ ef): Result[DbErrorKind, a] \ (ef - {Sqlitefx.Db, Sqlitefx.SqlSavepoint, RawSql}) + IO =
        DbError.runWithKind(() -> RawSql.runWithAllow(() -> Jdbc.withConnection(Db.connection(url), f)))

    def connected(f: Unit -> a \ ef): Result[DbErrorKind, a] \ (ef - {Sqlitefx.Db, Sqlitefx.SqlSavepoint, RawSql}) + IO =
        connectedTo(TestSupport.url(), _ -> f())

    /// A round of a load sends rows to several tables under one savepoint, so a failure at the last of them has to leave none of the others behind, and the round after it still lands.
    @Test
    def aFailedRoundLeavesNoneOfItsRowsBehind(): Unit \ {Assert, IO} =
        let refused = DbErrorKind.Other("the round was not what it should have been");
        let counted = connectedTo(TestSupport.url(), conn -> Tx.withTx(conn, () -> {
            discard Sqlitefx.Sql.execute("CREATE TABLE t (n int not null)", Nil);
            discard Sqlitefx.Sql.execute("INSERT INTO t VALUES (1)", Nil);
            discard Tx.withSavepoint("round", () -> {
                discard Sqlitefx.Sql.execute("INSERT INTO t VALUES (2)", Nil);
                discard Sqlitefx.Sql.execute("INSERT INTO t VALUES (3)", Nil);
                DbErr.raise(refused)
            });
            discard Tx.withSavepoint("round", () ->
                Sqlitefx.Sql.execute("INSERT INTO t VALUES (4)", Nil));
            Sqlitefx.Sql.fetch("SELECT n FROM t ORDER BY n", Nil)
        }));
        Assert.assertTrue(cells(counted) == Ok(
            (SqlValue.Int32(1) :: Nil) :: (SqlValue.Int32(4) :: Nil) :: Nil
        ))

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
            discard Sqlitefx.Sql.execute(table, Nil);
            Sqlitefx.Sql.fetch(
                "SELECT name FROM sqlite_master WHERE type = 'index'"
                    + " AND name LIKE 'sqlite_autoindex%' ORDER BY name", Nil)
        });
        Assert.assertTrue(cells(indexes(Db.Rounds.createTable())) == Ok(
            (SqlValue.Str("sqlite_autoindex_rounds_1") :: Nil) :: Nil
        ));
        Assert.assertTrue(cells(indexes(Db.Drivers.createTable())) == Ok(
            (SqlValue.Str("sqlite_autoindex_drivers_1") :: Nil) :: Nil
        ));
        Assert.assertTrue(cells(indexes(Db.CarDrivers.createTable())) == Ok(Nil));
        Assert.assertTrue(cells(indexes(Db.Cars.createTable())) == Ok(Nil));
        Assert.assertTrue(cells(indexes(Db.TimelineEvents.createTable())) == Ok(Nil))

    /// A round's laps are one statement, so a database that refuses them leaves none of the round's rows behind rather than some of them.
    @Test
    def aRefusedLoadLeavesWhatWasThereAlone(): Unit \ {Assert, IO} =
        let rows = LapRow.fromRawLaps(1, TestLapRow.sampleLap() :: Nil);
        let outcome = connected(() -> {
            let accepted = DbError.runWithKind(() -> { Laps.create(); Laps.insertRows(rows) });
            let refused  = DbError.runWithKind(() -> Laps.insertRows(rows));
            let counted  = Sqlitefx.Sql.fetch("SELECT COUNT(*) FROM laps", Nil) |> List.map(row -> Vector.toList(row#cells));
            (accepted, refused, counted)
        });
        match outcome {
            case Ok((accepted, refused, counted)) =>
                Assert.assertTrue(accepted == Ok(1));
                Assert.assertTrue(Result.isErr(refused));
                Assert.assertTrue(counted == (SqlValue.Int32(1) :: Nil) :: Nil)
            case Err(_) => Assert.assertTrue(false)
        }

    /// An aggregate answers in a number the driver found rather than one the
    /// schema declared, and a reading takes it without going through text.
    @Test
    def aNumberTheDriverFoundIsReadAsOne(): Unit \ {Assert, IO} =
        let sel = Sql.intOf(Sql.raw("total"));
        let result = connected(() -> Sqlitefx.Sql.fetch("select 3 + 4 as total", Nil));
        match Result.map(List.head, result) {
            case Ok(Some(row)) => Assert.assertTrue(Sql.decode(sel, row) == Ok(7))
            case _             => Assert.assertTrue(false)
        }

    /// A join projecting a column of each side under one name reads each at its own place.
    @Test
    def twoColumnsOfOneNameAreReadInTheOrderProjected(): Unit \ {Assert, IO} =
        let sel = Sql.Project.sel((Sql.intOf(Sql.raw("a.n")), Sql.intOf(Sql.raw("b.n"))));
        let result = connected(() -> Sqlitefx.Sql.fetch("SELECT a.n, b.n FROM (SELECT 1 AS n) a, (SELECT 2 AS n) b", Nil));
        match Result.map(List.head, result) {
            case Ok(Some(row)) => Assert.assertTrue(Sql.decode(sel, row) == Ok((1, 2)))
            case _             => Assert.assertTrue(false)
        }

    // --------------------------------------------------------- a file database

    /// The tests above connect to an in-memory database, which is neither
    /// created on a path nor journalled. What a run computes in is a file, so
    /// what `Db.connection` opens one as is driven here.

    /// A database of its own per test, under a directory that does not exist,
    /// which is what a working copy's `.db` is on a first run.
    def onFile(f: Connection -> a \ ef): (String, Result[DbErrorKind, a]) \ (ef - {Sqlitefx.Db, Sqlitefx.SqlSavepoint, RawSql}) + IO =
        let stem = File.createTempFile("motorsport-test", "");
        discard stem.delete();
        let path = "${stem.getPath()}/motorsport.sqlite";
        (path, connectedTo("jdbc:sqlite:${path}", f))

    def remove(path: String): Unit \ IO =
        List.forEach(suffix -> discard new File("${path}${suffix}").delete(), "" :: "-wal" :: "-shm" :: Nil);
        match Object.toOption(new File(path).getParentFile()) {
            case Some(parent) => discard parent.delete()
            case None         => ()
        }

    /// SQLite creates the file and not the directory holding it, so a URL
    /// naming one that does not exist reaches no database at all.
    @Test
    def connectingMakesTheDirectoryTheFileNeeds(): Unit \ {Assert, IO} =
        let (path, result) = onFile(_ -> Sqlitefx.Sql.fetch("select 1", Nil));
        Assert.assertTrue(cells(result) == Ok((SqlValue.Int32(1) :: Nil) :: Nil));
        Assert.assertTrue(new File(path).exists());
        remove(path)

    /// The server answers on a pool and connects per request, so a read has to
    /// run beside a writing run rather than behind it.
    @Test
    def aFileDatabaseIsJournalledForConcurrentReaders(): Unit \ {Assert, IO} =
        let (path, result) = onFile(_ -> Sqlitefx.Sql.fetch("PRAGMA journal_mode", Nil));
        Assert.assertTrue(cells(result) == Ok((SqlValue.Str("wal") :: Nil) :: Nil));
        remove(path)

    /// Two connections at once, which an in-memory database cannot be: each
    /// connection to one is a database of its own.
    @Test
    def aSecondConnectionReadsWhatTheFirstCommitted(): Unit \ {Assert, IO} =
        let (path, written) = onFile(conn -> Tx.withTx(conn, load));
        let readBack = counted(path);
        Assert.assertTrue(written == Ok(1));
        Assert.assertTrue(cells(readBack) == Ok((SqlValue.Int32(1) :: Nil) :: Nil));
        remove(path)

    /// A transaction that answers with an error takes back what it sent: the `DROP TABLE` a rebuild opens with is undone with the rows, so the table is not there to be read at all.
    @Test
    def aTransactionThatFailedTakesBackWhatItSent(): Unit \ {Assert, IO} =
        let (path, written) = onFile(conn -> Tx.withTx(conn, refuse));
        Assert.assertTrue(written == Err(DbErrorKind.Other("the round was not what it should have been")));
        Assert.assertTrue(Result.isErr(counted(path)));
        remove(path)

    /// A round loaded and then judged unfit, which is a transaction answering
    /// with an error.
    def refuse(): Int32 \ DbWrite + RawSql =
        discard load();
        DbErr.raise(DbErrorKind.Other("the round was not what it should have been"))

    def load(): Int32 \ DbWrite + RawSql =
        Laps.create();
        Laps.insertRows(LapRow.fromRawLaps(1, TestLapRow.sampleLap() :: Nil))

    /// From a connection of its own, so what it counts is what was committed.
    def counted(path: String): Result[DbErrorKind, List[Row]] \ IO =
        connectedTo("jdbc:sqlite:${path}", _ -> Sqlitefx.Sql.fetch("SELECT COUNT(*) FROM laps", Nil))

}
