/// Handlers standing in for a database, for a test whose subject is the query
/// and the reading of what it came back as.
pub mod Lite3fx.DbTest {

    use Lite3fx.RawSql
    use Lite3fx.SqlRead
    use Lite3fx.SqlSavepoint
    use Lite3fx.SqlWrite
    use Lite3fx.DbError.DbErrorKind
    use Lite3fx.Recording.Statement
    use Lite3fx.Row.Row

    /// Every `SELECT` is answered with the same rows.
    pub def runWithRows(rows: List[Row], f: Unit -> a \ ef): a \ (ef - {RawSql, SqlRead, SqlSavepoint}) =
        let outcome = run {
            Lite3fx.Db.catchAll(() -> Lite3fx.RawSql.runWithAllow(f))
        } with handler SqlRead {
            def fetch(_sql, _params, k) = k(Ok(rows))
        } with handler SqlSavepoint {
            def control(_command, k) = k(Ok(()))
        };
        Lite3fx.Db.rethrowing(outcome)

    /// The rows a `SELECT` is answered with, chosen by its text. A statement no
    /// answer is named for comes back with no rows.
    ///
    /// The text rather than the parsed query: a query no combinator here builds --
    /// a `WITH`, a `json_each` -- has to be answerable too.
    pub def runWithTable(rowsFor: String -> Option[List[Row]], f: Unit -> a \ ef): a \ (ef - {RawSql, SqlRead, SqlSavepoint}) =
        let outcome = run {
            Lite3fx.Db.catchAll(() -> Lite3fx.RawSql.runWithAllow(f))
        } with handler SqlRead {
            def fetch(sql, _params, k) = k(Ok(Option.getWithDefault(Nil, rowsFor(sql))))
        } with handler SqlSavepoint {
            def control(_command, k) = k(Ok(()))
        };
        Lite3fx.Db.rethrowing(outcome)

    /// The statements `f` sends, kept, and every `SELECT` answered with `rows`.
    /// A write answers with `affected` rows, which is what a caller that reads the
    /// round it just wrote needs in order to read the count back.
    pub def runRecording(
        rows: List[Row],
        affected: Int32,
        f: Unit -> a \ ef
    ): (a, List[Statement]) \ (ef - {RawSql, SqlRead, SqlWrite, SqlSavepoint}) =
        runRecordingWith(_ -> Some(rows), affected, f)

    /// As `runRecording`, with the rows a `SELECT` is answered with chosen by its
    /// text, so a caller sending several can be answered apart.
    pub def runRecordingWith(
        rowsFor: String -> Option[List[Row]],
        affected: Int32,
        f: Unit -> a \ ef
    ): (a, List[Statement]) \ (ef - {RawSql, SqlRead, SqlWrite, SqlSavepoint}) =
        region rc {
            let log = Ref.fresh(rc, (Nil: List[Statement]));
            let keep = statement -> Ref.put(statement :: Ref.get(log), log);
            let outcome = run {
                Lite3fx.Db.catchAll(() -> Lite3fx.RawSql.runWithAllow(f))
            } with handler SqlWrite {
                def execute(sql, params, k) = {
                    keep(Statement.Execute(sql, params));
                    k(Ok(affected))
                }
                def executeReturning(sql, params, k) = {
                    keep(Statement.Execute(sql, params));
                    k(Ok(rowsFor(sql) |> Option.getWithDefault(Nil)))
                }
                def insertMany(sql, rows, k) = {
                    keep(Statement.InsertMany(sql, rows));
                    k(Ok(List.length(rows)))
                }
                def commit(k) = { keep(Statement.Commit); k(Ok()) }
                def rollback(k) = { keep(Statement.Rollback); k(Ok()) }
            } with handler SqlRead {
                def fetch(sql, params, k) = {
                    keep(Statement.Fetch(sql, params));
                    k(Ok(Option.getWithDefault(Nil, rowsFor(sql))))
                }
            } with handler SqlSavepoint {
                def control(command, k) = {
                    keep(Statement.Execute(Lite3fx.Savepoint.toSql(command), Nil));
                    k(Ok())
                }
            };
            (Lite3fx.Db.rethrowing(outcome), List.reverse(Ref.get(log)))
        }

    /// A database that answers every statement with the same failure, for a
    /// caller whose subject is what it does about one.
    pub def runFailing(kind: DbErrorKind, f: Unit -> a \ ef): a \ (ef - {RawSql, SqlRead, SqlWrite, SqlSavepoint}) =
        let outcome = run {
            run {
                Lite3fx.Db.catchAll(() -> Lite3fx.RawSql.runWithAllow(f))
            } with handler SqlWrite {
                def execute(_sql, _params, k) = k(Err(kind))
                def executeReturning(_sql, _params, k) = k(Err(kind))
                def insertMany(_sql, _rows, k) = k(Err(kind))
                def commit(k) = k(Err(kind))
                def rollback(k) = k(Err(kind))
            }
        } with handler SqlRead {
            def fetch(_sql, _params, k) = k(Err(kind))
        } with handler SqlSavepoint {
            def control(_command, k) = k(Err(kind))
        };
        Lite3fx.Db.rethrowing(outcome)

    /// A database that refuses every write. A read is left to a handler outside, so
    /// one that answers rows can be put around this one.
    pub def runFailingWrite(kind: DbErrorKind, f: Unit -> a \ ef): a \ (ef - {RawSql, SqlWrite, SqlSavepoint}) =
        let outcome = run {
            Lite3fx.Db.catchAll(() -> Lite3fx.RawSql.runWithAllow(f))
        } with handler SqlWrite {
            def execute(_sql, _params, k) = k(Err(kind))
            def executeReturning(_sql, _params, k) = k(Err(kind))
            def insertMany(_sql, _rows, k) = k(Err(kind))
            def commit(k) = k(Err(kind))
            def rollback(k) = k(Err(kind))
        } with handler SqlSavepoint {
            def control(_command, k) = k(Ok(()))
        };
        Lite3fx.Db.rethrowing(outcome)

}
