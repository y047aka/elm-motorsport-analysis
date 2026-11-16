/// The trip between a Flix value and a JDBC one, in both directions.
///
/// The bind side is the type a `?` was given; the read side is the type SQLite
/// kept the value in, which is a per-value fact rather than the column's own.
pub mod Db.JdbcConvert {

    import java.sql.PreparedStatement
    import java.sql.ResultSet
    import java.sql.ResultSetMetaData
    import java.sql.Types

    use Db.Error
    use Db.NullType
    use Db.Value

    /// The bounds a `Value.Integer` reaches, which is what an `int` column holds.
    def intMin(): Int64 = -2147483648i64
    def intMax(): Int64 = 2147483647i64

    /// The value, put where the driver takes it.
    pub def bind(pstmt: PreparedStatement, index: Int32, value: Value): Unit \ IO =
        match value {
            case Value.Text(s)    => pstmt.setString(index, s)
            case Value.Integer(n) => pstmt.setInt(index, n)
            case Value.Real(n)    => pstmt.setDouble(index, n)
            case Value.Boolean(b) => pstmt.setBoolean(index, b)
            case Value.Json(xs)   => pstmt.setString(index, Db.jsonArray(xs))
            case Value.Null       => pstmt.setNull(index, Types.NULL)
            case Value.NullOf(t)  => pstmt.setNull(index, match t {
                case NullType.Text    => Types.VARCHAR
                case NullType.Integer => Types.INTEGER
            })
        }

    /// The cell, in whichever type the driver found it in.
    ///
    /// A count the driver answered in a long beyond what an `int` column holds
    /// arrives as its text, which is the one form a reading reports unread --
    /// as it does for any number it cannot take.
    pub def cell(rs: ResultSet, index: Int32): Value \ IO =
        let found = rs.getObject(index);
        if (Object.isNull(found))
            Value.Null
        else match found.getClass().getName() {
            case "java.lang.Integer" => Value.Integer(rs.getInt(index))
            case "java.lang.Long"    =>
                if (rs.getLong(index) >= intMin() and rs.getLong(index) <= intMax())
                    Value.Integer(rs.getInt(index))
                else
                    Value.Text(rs.getString(index))
            case "java.lang.Double"  => Value.Real(rs.getDouble(index))
            case "java.lang.Float"   => Value.Real(rs.getDouble(index))
            case _                   => Value.Text(rs.getString(index))
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
