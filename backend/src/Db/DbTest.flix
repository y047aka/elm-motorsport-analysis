/// Handlers standing in for a database, for a test whose subject is the query
/// and the reading of what it came back as.
///
/// `Db.runRecording` is the other kind: it keeps what was sent and answers
/// nothing, which is what a caller that reads the round it just wrote needs to
/// fail on. These answer, and so are where a `SELECT` and its reading are
/// driven together without a database.
///
/// A JVM failure thrown inside a thunk is picked up directly under the `run` and
/// rethrown once the caller's own handlers are back in place, which is what
/// keeps a `run` with no catch of its own out of the paths callers use.
pub mod Db.DbTest {

    use Db.Error
    use Db.Row.Row

    /// Every `SELECT` is answered with the same rows. The least a reading needs
    /// to be driven without a database.
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
    /// The text rather than the parsed query, since a query no combinator here
    /// builds -- a `WITH`, a `json_each` -- is one of these has to answer too.
    pub def runWithTable(rowsFor: String -> Option[List[Row]], f: Unit -> a \ ef): a \ (ef - {RawSql, SqlRead, SqlSavepoint}) =
        let outcome = run {
            Db.catchAll(() -> RawSql.runWithAllow(f))
        } with handler SqlRead {
            def fetch(sql, _params, k) = k(Ok(Option.getWithDefault(Nil, rowsFor(sql))))
        } with handler SqlSavepoint {
            def control(_command, k) = k(Ok(()))
        };
        Db.rethrowing(outcome)

    /// A database that refuses every write, for a caller whose subject is what it
    /// does about a refusal. A read is left to a handler outside, which is what
    /// lets one that answers rows be put around this one.
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
