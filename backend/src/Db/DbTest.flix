/// Handlers standing in for a database, for a test whose subject is the query
/// and the reading of what it came back as.
///
/// `Db.runRecording` is the narrower kind: it keeps what was sent and answers a read
/// with nothing, so a read no one meant to send fails rather than coming back
/// empty. `runRecording` here answers as well as keeps.
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

    /// The statements `f` sends, kept, and every `SELECT` answered with `rows`.
    /// A write answers with `affected` rows, which is what a caller that reads the
    /// round it just wrote needs in order to read the count back.
    pub def runRecording(
        rows: List[Row],
        affected: Int32,
        f: Unit -> a \ ef
    ): (a, List[Db.Statement]) \ (ef - {RawSql, SqlRead, SqlWrite, SqlSavepoint}) =
        runRecordingWith(_ -> Some(rows), affected, f)

    /// As `runRecording`, with the rows a `SELECT` is answered with chosen by its
    /// text, so a caller sending several can be answered apart.
    pub def runRecordingWith(
        rowsFor: String -> Option[List[Row]],
        affected: Int32,
        f: Unit -> a \ ef
    ): (a, List[Db.Statement]) \ (ef - {RawSql, SqlRead, SqlWrite, SqlSavepoint}) =
        region rc {
            let log = Ref.fresh(rc, (Nil: List[Db.Statement]));
            let keep = statement -> Ref.put(statement :: Ref.get(log), log);
            let outcome = run {
                Db.catchAll(() -> RawSql.runWithAllow(f))
            } with handler SqlWrite {
                def execute(sql, params, k) = {
                    keep(Db.Statement.Execute(sql, params));
                    k(Ok(affected))
                }
                def insertMany(sql, rows, k) = {
                    keep(Db.Statement.InsertMany(sql, rows));
                    k(Ok(List.length(rows)))
                }
                def commit(k) = { keep(Db.Statement.Commit); k(Ok()) }
                def rollback(k) = { keep(Db.Statement.Rollback); k(Ok()) }
            } with handler SqlRead {
                def fetch(sql, params, k) = {
                    keep(Db.Statement.Fetch(sql, params));
                    k(Ok(Option.getWithDefault(Nil, rowsFor(sql))))
                }
            } with handler SqlSavepoint {
                def control(command, k) = {
                    keep(Db.Statement.Execute(Db.Savepoint.toSql(command), Nil));
                    k(Ok())
                }
            };
            (Db.rethrowing(outcome), List.reverse(Ref.get(log)))
        }

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
