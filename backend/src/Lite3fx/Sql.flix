/// What a caller sends rather than the operations themselves, which no module
/// outside these files calls: the failure a handler answered with becomes a
/// raised one here, where the caller's own handlers are installed.
pub mod Lite3fx.Sql {

    use Lite3fx.DbErr
    use Lite3fx.DbRead
    use Lite3fx.DbWrite
    use Lite3fx.DbError
    use Lite3fx.DbError.DbErrorKind
    use Lite3fx.RawSql
    use Lite3fx.Row.Row
    use Lite3fx.SqlRead
    use Lite3fx.SqlValue.SqlValue
    use Lite3fx.SqlWrite
    use Lite3fx.TransientDbErr

    /// The value, or the failure that ended the reading, raised in the caller's
    /// own context.
    pub def orRaise(result: Result[DbErrorKind, a]): a \ {TransientDbErr, DbErr} =
        match result {
            case Ok(value) => value
            case Err(kind) => DbError.raise(kind)
        }

    pub def fetch(sql: String, params: List[SqlValue]): List[Row] \ DbRead + RawSql =
        RawSql.allow(sql);
        SqlRead.fetch(sql, params) |> orRaise

    /// The number of rows the database took, which for a statement touching no
    /// table -- a `CREATE TABLE`, a `SAVEPOINT` -- is nothing to say.
    pub def execute(sql: String, params: List[SqlValue]): Int32 \ DbWrite + RawSql =
        RawSql.allow(sql);
        SqlWrite.execute(sql, params) |> orRaise

    /// A statement written `RETURNING`, which answers with rows as a `SELECT`
    /// does. SQLite has answered them since 3.35.
    pub def executeReturning(sql: String, params: List[SqlValue]): List[Row] \ DbWrite + RawSql =
        RawSql.allow(sql);
        SqlWrite.executeReturning(sql, params) |> orRaise

    /// The rows, bound one at a time to one statement, and the number the
    /// database took.
    pub def insertMany(sql: String, rows: List[List[SqlValue]]): Int32 \ DbWrite + RawSql =
        RawSql.allow(sql);
        SqlWrite.insertMany(sql, rows) |> orRaise

}
