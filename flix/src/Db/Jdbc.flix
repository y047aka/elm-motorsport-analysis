mod Db.Jdbc {

    import java.sql.Connection
    import java.sql.DriverManager
    import java.sql.PreparedStatement
    import java.sql.ResultSet
    import java.sql.Savepoint
    import java.sql.SQLException
    import java.sql.Types

    import java.io.File

    import org.sqlite.JDBC

    use Db.Error
    use Db.Value

    def batchSize(): Int32 = 1000

    /// What a refusal was. SQLite answers a lock it waited out with
    /// `SQLITE_BUSY`, and its extended codes carry the primary one in their
    /// low byte -- `SQLITE_BUSY_SNAPSHOT` is 517, which is 5.
    pub def classify(code: Int32, message: String): Error =
        match Int32.remainder(code, 256) {
            case 5 => Error.Busy(message)
            case 6 => Error.Busy(message)
            case _ => Error.Refused(message)
        }

    def refusal(e: SQLException): Error \ IO =
        let code: Int32 = e.getErrorCode();
        classify(code, "${e.getMessage()}")

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
            case e: SQLException => Err(Error.Unreachable("${e.getMessage()}"))
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

    pub def runWith(conn: Connection, f: Unit -> a \ ef): a \ (ef - Db) + IO =
        run {
            runWriting(conn, f)
        } with handler DbRead {
            def fetch(sql, params, k) = k(runFetch(conn, sql, params))
        }

    /// The connection as a read alone, which is what the server answers a
    /// request through.
    pub def runReading(conn: Connection, f: Unit -> a \ ef): a \ (ef - DbRead) + IO =
        run {
            f()
        } with handler DbRead {
            def fetch(sql, params, k) = k(runFetch(conn, sql, params))
        }

    pub def runWriting(conn: Connection, f: Unit -> a \ ef): a \ (ef - DbWrite) + IO =
        run {
            f()
        } with handler DbWrite {
            def execute(sql, k) = k(runStatement(conn, sql))
            def insertMany(sql, rows, k) = k(insertRows(conn, sql, rows))
            def commit(k) = k(endTransaction(conn, c -> c.commit()))
            def rollback(k) = k(endTransaction(conn, c -> c.rollback()))
        }

    def runFetch(conn: Connection, sql: String, params: List[Value]): Result[Error, List[List[Option[String]]]] \ IO =
        try {
            let stmt = conn.prepareStatement(sql);
            bind(stmt, params);
            let rs = stmt.executeQuery();
            let width = rs.getMetaData().getColumnCount();
            let rows = readRows(rs, width, Nil);
            rs.close();
            stmt.close();
            Ok(rows)
        } catch {
            case e: SQLException => Err(refusal(e))
        }

    def readRows(rs: ResultSet, width: Int32, acc: List[List[Option[String]]]): List[List[Option[String]]] \ IO =
        if (rs.next())
            readRows(rs, width, readRow(rs, 1, width, Nil) :: acc)
        else
            List.reverse(acc)

    def readRow(rs: ResultSet, index: Int32, width: Int32, acc: List[Option[String]]): List[Option[String]] \ IO =
        if (index > width)
            List.reverse(acc)
        else
            readRow(rs, index + 1, width, cell(rs, index) :: acc)

    def cell(rs: ResultSet, index: Int32): Option[String] \ IO =
        let value = rs.getString(index);
        if (rs.wasNull()) None else Some(value)

    def runStatement(conn: Connection, sql: String): Result[Error, Unit] \ IO =
        try {
            let stmt = conn.createStatement();
            discard stmt.executeUpdate(sql);
            stmt.close();
            Ok()
        } catch {
            case e: SQLException => Err(refusal(e))
        }

    /// The rows go out in batches, so a refusal partway through has already
    /// sent some of them. They are undone against a savepoint rather than by
    /// rolling the transaction back: what a run loaded before this call is
    /// still to be committed.
    def insertRows(conn: Connection, sql: String, rows: List[List[Value]]): Result[Error, Int32] \ IO =
        match savepoint(conn) {
            case Err(e) => Err(e)
            case Ok(mark) =>
                let outcome = try {
                    let pstmt = conn.prepareStatement(sql);
                    let count = List.foldLeft((sent, row) -> {
                        bind(pstmt, row);
                        pstmt.addBatch();
                        if (Int32.remainder(sent + 1, batchSize()) == 0) discard pstmt.executeBatch() else ();
                        sent + 1
                    }, 0, rows);
                    discard pstmt.executeBatch();
                    pstmt.close();
                    Ok(count)
                } catch {
                    case e: SQLException => Err(refusal(e))
                };
                match outcome {
                    case Ok(count) => release(conn, mark); Ok(count)
                    case Err(e)    => undo(conn, mark); Err(e)
                }
        }

    def savepoint(conn: Connection): Result[Error, Savepoint] \ IO =
        try {
            Ok(conn.setSavepoint())
        } catch {
            case e: SQLException => Err(refusal(e))
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
        List.forEachWithIndex((index, value) -> bindOne(pstmt, index + 1, value), values)

    def bindOne(pstmt: PreparedStatement, index: Int32, value: Value): Unit \ IO =
        match value {
            case Value.Text(s)    => pstmt.setString(index, s)
            case Value.Integer(n) => pstmt.setInt(index, n)
            case Value.Boolean(b) => pstmt.setBoolean(index, b)
            case Value.NullableInteger(o) => match o {
                case Some(n) => pstmt.setInt(index, n)
                case None    => pstmt.setNull(index, Types.INTEGER)
            }
            case Value.NullableIntArray(o) => match o {
                case Some(xs) => pstmt.setString(index, Db.jsonArray(xs))
                case None     => pstmt.setNull(index, Types.VARCHAR)
            }
        }

    def endTransaction(conn: Connection, end: Connection -> Unit \ IO): Result[Error, Unit] \ IO =
        try {
            end(conn);
            Ok()
        } catch {
            case e: SQLException => Err(refusal(e))
        }

}
