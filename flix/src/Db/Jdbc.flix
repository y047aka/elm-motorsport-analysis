mod Db.Jdbc {

    import java.sql.Connection
    import java.sql.DriverManager
    import java.sql.PreparedStatement
    import java.sql.ResultSet
    import java.sql.SQLException
    import java.sql.Types

    import org.postgresql.Driver

    use Db.LapRow
    use Db.LapRow.LapRow
    use Db.LapRow.Value
    use Db.Schema

    def batchSize(): Int32 = 1000

    /// The driver registers itself through `META-INF/services` when the JDBC jar
    /// is on the application class path. It is not on the one Flix runs with, so
    /// without `registerDriver` this reports that no driver matches the URL —
    /// at run time, from a program that compiled and whose `import` resolved.
    pub def connect(url: String): Result[String, Connection] \ IO =
        try {
            DriverManager.registerDriver(new Driver());
            let conn = DriverManager.getConnection(url);
            conn.setAutoCommit(false);
            Ok(conn)
        } catch {
            case e: SQLException => Err("could not connect (caused by: ${e.getMessage()})")
        }

    pub def close(conn: Connection): Unit \ IO =
        try {
            conn.close()
        } catch {
            case _e: SQLException => ()
        }

    pub def runWith(conn: Connection, f: Unit -> a \ ef): a \ (ef - Db) + IO =
        run {
            f()
        } with handler Db {
            def execute(sql, k) = k(runStatement(conn, sql))
            def insertLaps(rows, k) = k(insertRows(conn, rows))
            def fetch(sql, k) = k(runFetch(conn, sql))
        }

    def runFetch(conn: Connection, sql: String): Result[String, List[List[Option[String]]]] \ IO =
        try {
            let stmt = conn.createStatement();
            let rs = stmt.executeQuery(sql);
            let width = rs.getMetaData().getColumnCount();
            let rows = readRows(rs, width, Nil);
            rs.close();
            stmt.close();
            conn.commit();
            Ok(rows)
        } catch {
            case e: SQLException => rollback(conn); Err("${e.getMessage()}")
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

    def runStatement(conn: Connection, sql: String): Result[String, Unit] \ IO =
        try {
            let stmt = conn.createStatement();
            discard stmt.executeUpdate(sql);
            stmt.close();
            conn.commit();
            Ok()
        } catch {
            case e: SQLException => rollback(conn); Err("${e.getMessage()}")
        }

    def insertRows(conn: Connection, rows: List[LapRow]): Result[String, Int32] \ IO =
        try {
            let pstmt = conn.prepareStatement(Schema.insert());
            let count = List.foldLeft((sent, row) -> {
                bind(pstmt, LapRow.values(row));
                pstmt.addBatch();
                if (Int32.remainder(sent + 1, batchSize()) == 0) discard pstmt.executeBatch() else ();
                sent + 1
            }, 0, rows);
            discard pstmt.executeBatch();
            pstmt.close();
            conn.commit();
            Ok(count)
        } catch {
            case e: SQLException => rollback(conn); Err("${e.getMessage()}")
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
                case Some(xs) => pstmt.setString(index, LapRow.arrayLiteral(xs))
                case None     => pstmt.setNull(index, Types.VARCHAR)
            }
        }

    def rollback(conn: Connection): Unit \ IO =
        try {
            conn.rollback()
        } catch {
            case _e: SQLException => ()
        }

}
