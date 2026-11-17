pub mod Db.Jdbc {

    import java.sql.Connection
    import java.sql.DriverManager
    import java.sql.PreparedStatement
    import java.sql.ResultSet
    import java.sql.Savepoint
    import java.sql.SQLException
    import java.sql.Types

    import java.lang.Throwable

    import java.io.File

    import org.sqlite.JDBC

    use Db.Error
    use Db.JdbcConvert
    use Db.Row.Row
    use Db.Savepoint
    use Db.Value

    def batchSize(): Int32 = 1000

    /// The driver registers itself through `META-INF/services` when the JDBC jar
    /// is on the application class path. It is not on the one Flix runs with, so
    /// without `registerDriver` this reports that no driver matches the URL —
    /// at run time, from a program that compiled and whose `import` resolved.
    ///
    /// SQLite creates the database file and not the directory holding it, so a
    /// URL naming one that does not exist reports that the file cannot be
    /// opened.
    pub def connect(url: String): Result[Error, Connection] \ IO =
        try {
            DriverManager.registerDriver(new JDBC());
            makeParentDirectory(url);
            let conn = DriverManager.getConnection(url);
            pragmas(conn);
            conn.setAutoCommit(false);
            Ok(conn)
        } catch {
            case e: SQLException => Err(Db.unreachable("${e.getMessage()}"))
        }

    def makeParentDirectory(url: String): Unit \ IO =
        match String.stripPrefix({substr = "jdbc:sqlite:"}, url) {
            case Some(path) if not String.startsWith({prefix = ":"}, path) =>
                match Object.toOption(new File(path).getParentFile()) {
                    case Some(parent) => discard parent.mkdirs()
                    case None         => ()
                }
            case _ => ()
        }

    /// The server answers on a pool of eight and connects per request, so a
    /// read has to run beside a writing run rather than behind it. Set before
    /// the first transaction opens: `journal_mode` cannot be changed inside
    /// one.
    def pragmas(conn: Connection): Unit \ IO =
        let stmt = conn.createStatement();
        discard stmt.execute("PRAGMA journal_mode = WAL");
        discard stmt.execute("PRAGMA busy_timeout = 5000");
        stmt.close()

    pub def close(conn: Connection): Unit \ IO =
        try {
            conn.close()
        } catch {
            case _e: SQLException => ()
        }

    /// A database opened, read or written, and closed however that went --
    /// which is the whole of what a run or a test does with one.
    ///
    /// The close is on every way out, including the one that throws: a
    /// connection left open holds a read on the database until the process ends.
    pub def withConnection(url: String, f: Unit -> a \ ef): a \ (ef - Db) + IO + {TransientDbErr, DbErr} =
        let conn = Db.orRaise(connect(url));
        let outcome = try {
            Db.runWithError(() -> Db.guard(() -> runWith(conn, f)))
        } catch {
            case error: Throwable => close(conn); Db.rethrowing(Err(error))
        };
        close(conn);
        Db.orRaise(outcome)

    /// A driver's failure that is not an `SQLException` is still a failure of
    /// the database, and a fatal one is not a failure to keep.
    def guarded(f: Unit -> Result[Error, a] \ IO): Result[Error, a] \ IO =
        match Db.catchAll(f) {
            case Ok(result) => result
            case Err(error) =>
                if (Db.isFatal(error)) Db.rethrowing(Err(error))
                else Err(Db.Error.Other(Db.describeThrowable(error)))
        }

    pub def runWith(conn: Connection, f: Unit -> a \ ef): a \ (ef - {RawSql, SqlRead, SqlWrite, SqlSavepoint}) + IO =
        RawSql.runWithAllow(() -> run {
            run {
                runWriting(conn, f)
            } with handler SqlRead {
                def fetch(sql, params, k) = k(guarded(() -> fetchRows(conn, sql, params)))
            }
        } with handler SqlSavepoint {
            def control(command, k) =
                k(guarded(() -> executeStatement(conn, Savepoint.toSql(command), Nil) |> Result.map(_ -> ())))
        })

    /// The connection as a read alone, which is what the server answers a
    /// request through.
    pub def runReading(conn: Connection, f: Unit -> a \ ef): a \ (ef - SqlRead) + IO =
        run {
            f()
        } with handler SqlRead {
            def fetch(sql, params, k) = k(guarded(() -> fetchRows(conn, sql, params)))
        }

    pub def runWriting(conn: Connection, f: Unit -> a \ ef): a \ (ef - SqlWrite) + IO =
        run {
            f()
        } with handler SqlWrite {
            def execute(sql, params, k) = k(guarded(() -> executeStatement(conn, sql, params)))
            def insertMany(sql, rows, k) = k(guarded(() -> insertRows(conn, sql, rows)))
            def commit(k) = k(guarded(() -> endTransaction(conn, c -> c.commit())))
            def rollback(k) = k(guarded(() -> endTransaction(conn, c -> c.rollback())))
        }

    /// The statement is closed on every way out, including the one that throws:
    /// a statement left open holds the read on the database until the process
    /// ends, which is what a server that answers one request at a time would
    /// then never come back from.
    def fetchRows(conn: Connection, sql: String, params: List[Value]): Result[Error, List[Row]] \ IO =
        match prepared(conn, sql) {
            case Err(failure) => Err(failure)
            case Ok(stmt) =>
                let outcome = try {
                    bind(stmt, params);
                    let rs = stmt.executeQuery();
                    Ok(readRows(rs, JdbcConvert.labels(rs), Nil))
                } catch {
                    case e: SQLException => Err(refusal(sql, e))
                };
                discard guarded(() -> {
                    stmt.close();
                    Ok()
                });
                outcome
        }

    def readRows(rs: ResultSet, names: List[String], acc: List[Row]): List[Row] \ IO =
        if (rs.next())
            readRows(rs, names, Row.of(names, readCells(rs, 1, List.length(names), Nil)) :: acc)
        else
            List.reverse(acc)

    def readCells(rs: ResultSet, index: Int32, width: Int32, acc: List[Value]): List[Value] \ IO =
        if (index > width)
            List.reverse(acc)
        else
            readCells(rs, index + 1, width, JdbcConvert.cell(rs, index) :: acc)

    /// The statement is closed on every way out, including the one that throws.
    def executeStatement(conn: Connection, sql: String, params: List[Value]): Result[Error, Int32] \ IO =
        match prepared(conn, sql) {
            case Err(failure) => Err(failure)
            case Ok(stmt) =>
                let outcome = try {
                    bind(stmt, params);
                    Ok(stmt.executeUpdate())
                } catch {
                    case e: SQLException => Err(refusal(sql, e))
                };
                discard guarded(() -> {
                    stmt.close();
                    Ok()
                });
                outcome
        }

    /// A statement the database will not take is refused at the preparing of it, so
    /// that is where the statement still has to be in hand to say so.
    def prepared(conn: Connection, sql: String): Result[Error, PreparedStatement] \ IO =
        try {
            Ok(conn.prepareStatement(sql))
        } catch {
            case e: SQLException => Err(refusal(sql, e))
        }

    /// The rows go out in batches, so a refusal partway through has already
    /// sent some of them. They are undone against a savepoint rather than by
    /// rolling the transaction back: what a run loaded before this call is
    /// still to be committed.
    def insertRows(conn: Connection, sql: String, rows: List[List[Value]]): Result[Error, Int32] \ IO =
        match savepoint(conn) {
            case Err(e) => Err(e)
            case Ok(mark) =>
                let pstmt = conn.prepareStatement(sql);
                let outcome = try {
                    let count = List.foldLeft((sent, row) -> {
                        bind(pstmt, row);
                        pstmt.addBatch();
                        if (Int32.remainder(sent + 1, batchSize()) == 0) discard pstmt.executeBatch() else ();
                        sent + 1
                    }, 0, rows);
                    discard pstmt.executeBatch();
                    Ok(count)
                } catch {
                    case e: SQLException => Err(refusal(sql, e))
                };
                discard guarded(() -> {
                    pstmt.close();
                    Ok()
                });
                match outcome {
                    case Ok(count) => release(conn, mark); Ok(count)
                    case Err(e)    => undo(conn, mark); Err(e)
                }
        }

    def savepoint(conn: Connection): Result[Error, Savepoint] \ IO =
        try {
            Ok(conn.setSavepoint())
        } catch {
            case e: SQLException => Err(refusal("SAVEPOINT", e))
        }

    def release(conn: Connection, mark: Savepoint): Unit \ IO =
        try {
            conn.releaseSavepoint(mark)
        } catch {
            case _e: SQLException => ()
        }

    def undo(conn: Connection, mark: Savepoint): Unit \ IO =
        try {
            conn.rollback(mark)
        } catch {
            case _e: SQLException => ()
        }

    def bind(pstmt: PreparedStatement, values: List[Value]): Unit \ IO =
        List.forEachWithIndex((index, value) -> JdbcConvert.bind(pstmt, index + 1, value), values)

    def endTransaction(conn: Connection, end: Connection -> Unit \ IO): Result[Error, Unit] \ IO =
        try {
            end(conn);
            Ok()
        } catch {
            case e: SQLException => Err(refusal("the transaction's end", e))
        }

    /// What a refusal was. The code is the driver's own; the message is what it
    /// said, which for some failures of its own it leaves unsaid.
    ///
    /// The driver names what it could not resolve and never the statement it was
    /// written into, which is why `statement` rides along.
    def refusal(statement: String, e: SQLException): Error \ IO =
        let message: String = e.getMessage();
        let said: String = if (Object.isNull(message)) "${e.getClass().getName()}" else message;
        match Db.Sqlite.classify({code = e.getErrorCode(), message = said}) {
            case Db.Error.Refused(why)   => Db.Error.Refused("${why}: ${String.take(220, statement)}")
            case other                   => other
        }

}
