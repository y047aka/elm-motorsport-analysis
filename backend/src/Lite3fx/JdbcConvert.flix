/// The trip between a Flix value and a JDBC one, in both directions.
///
/// The bind side is the type a `?` was given; the read side is the type SQLite
/// kept the value in, which is a per-value fact rather than the column's own.
pub mod Lite3fx.JdbcConvert {

    import java.sql.PreparedStatement
    import java.sql.ResultSet
    import java.sql.ResultSetMetaData
    import java.sql.Types

    use Lite3fx.SqlValue.NullType
    use Lite3fx.SqlValue.SqlValue

    /// The value, put where the driver takes it.
    pub def bind(pstmt: PreparedStatement, index: Int32, value: SqlValue): Unit \ IO =
        match value {
            case SqlValue.Str(s)   => pstmt.setString(index, s)
            case SqlValue.Json(t)  => pstmt.setString(index, t)
            case SqlValue.Int32(n) => pstmt.setInt(index, n)
            case SqlValue.Int64(n) => pstmt.setLong(index, n)
            case SqlValue.Float64(n) => pstmt.setDouble(index, n)
            case SqlValue.Bool(b)  => pstmt.setBoolean(index, b)
            case SqlValue.Null     => pstmt.setNull(index, Types.NULL)
            case SqlValue.NullOf(t) => pstmt.setNull(index, match t {
                case NullType.Str    => Types.VARCHAR
                case NullType.Json   => Types.VARCHAR
                case NullType.Int32  => Types.INTEGER
                case NullType.Int64  => Types.INTEGER
                case NullType.Bool   => Types.INTEGER
                case NullType.Float64 => Types.REAL
            })
        }

    /// The cell, in whichever type the driver found it in.
    ///
    /// A count the driver answered in a long stays a long: the reading that
    /// wants an `int` says so, and fails when the number is beyond one.
    pub def cell(rs: ResultSet, index: Int32): SqlValue \ IO =
        let found = rs.getObject(index);
        if (Object.isNull(found))
            SqlValue.Null
        else match found.getClass().getName() {
            case "java.lang.Integer" => SqlValue.Int32(rs.getInt(index))
            case "java.lang.Long"    => SqlValue.Int64(rs.getLong(index))
            case "java.lang.Double"  => SqlValue.Float64(rs.getDouble(index))
            case "java.lang.Float"   => SqlValue.Float64(rs.getDouble(index))
            case _                   => SqlValue.Str(rs.getString(index))
        }

    /// The columns a result came under, in the order the cells arrive in.
    ///
    /// The label rather than the name: what a query aliased is what the driver
    /// reports, and a query that aliased nothing reports the column.
    pub def labels(rs: ResultSet): List[String] \ IO =
        let meta = rs.getMetaData();
        walk(meta, meta.getColumnCount(), 1, Nil)

    def walk(meta: ResultSetMetaData, width: Int32, index: Int32, acc: List[String]): List[String] \ IO =
        if (index > width)
            List.reverse(acc)
        else
            walk(meta, width, index + 1, meta.getColumnLabel(index) :: acc)

}
