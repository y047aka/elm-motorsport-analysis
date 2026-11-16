/// Handlers standing in for a database, for a test whose subject is the query
/// and the reading of what it came back as.
///
/// `Db.runRecording` is the other kind: it keeps what was sent and answers a read
/// with nothing. These answer.
pub mod Db.DbTest {

    use Db.Error
    use Db.Row.Row

    /// Every `SELECT` is answered with the same rows.
    pub def runWithRows(rows: List[Row], f: Unit -> a \ ef): a \ (ef - {RawSql, SqlRead, SqlSavepoint}) =
        let outcome = run {
            Db.catchAll(() -> RawSql.runWithAllow(f))
        } with handler SqlRead {
            def fetch(_sql, _params, k) = k(Ok(rows))
        } with handler SqlSavepoint {
            def control(_command, k) = k(Ok(()))
        };
        Db.rethrowing(outcome)

    /// The rows a `SELECT` is answered with, chosen by its text. A statement no
    /// answer is named for comes back with no rows.
    ///
    /// The text rather than the parsed query: a query no combinator here builds --
    /// a `WITH`, a `json_each` -- has to be answerable too.
    pub def runWithTable(rowsFor: String -> Option[List[Row]], f: Unit -> a \ ef): a \ (ef - {RawSql, SqlRead, SqlSavepoint}) =
        let outcome = run {
            Db.catchAll(() -> RawSql.runWithAllow(f))
        } with handler SqlRead {
            def fetch(sql, _params, k) = k(Ok(Option.getWithDefault(Nil, rowsFor(sql))))
        } with handler SqlSavepoint {
            def control(_command, k) = k(Ok(()))
        };
        Db.rethrowing(outcome)

    /// A database that refuses every write. A read is left to a handler outside, so
    /// one that answers rows can be put around this one.
    pub def runFailingWrite(error: Error, f: Unit -> a \ ef): a \ (ef - {RawSql, SqlWrite, SqlSavepoint}) =
        let outcome = run {
            Db.catchAll(() -> RawSql.runWithAllow(f))
        } with handler SqlWrite {
            def execute(_sql, _params, k) = k(Err(error))
            def insertMany(_sql, _rows, k) = k(Err(error))
            def commit(k) = k(Err(error))
            def rollback(k) = k(Err(error))
        } with handler SqlSavepoint {
            def control(_command, k) = k(Ok(()))
        };
        Db.rethrowing(outcome)

}
