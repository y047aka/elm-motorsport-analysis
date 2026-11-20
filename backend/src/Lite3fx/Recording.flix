/// The statements a run sent, kept rather than sent.
///
/// Two callers want this: a test comparing what its code sent, and a route
/// answered with no database behind it at all -- the second answers a read with
/// the failure that nothing was sent, so a read no one meant to send fails
/// rather than coming back empty.
pub mod Lite3fx.Recording {

    use Lite3fx.DbError
    use Lite3fx.RawSql
    use Lite3fx.SqlRead
    use Lite3fx.SqlSavepoint
    use Lite3fx.SqlWrite
    use Lite3fx.SqlValue.SqlValue

    /// What a caller sent.
    pub enum Statement with Eq {
        case Execute(String, List[SqlValue])
        case InsertMany(String, List[List[SqlValue]])
        case Fetch(String, List[SqlValue])
        case Commit
        case Rollback
    }

    /// The statements `f` sends, kept, with nothing behind them.
    pub def statements(f: Unit -> a \ ef): (a, List[Statement]) \ (ef - {RawSql, SqlRead, SqlWrite, SqlSavepoint}) =
        region rc {
            let log = Ref.fresh(rc, (Nil: List[Statement]));
            let record = statement -> Ref.put(statement :: Ref.get(log), log);
            let outcome = run {
                run {
                    Lite3fx.Db.catchAll(() -> Lite3fx.RawSql.runWithAllow(f))
                } with handler SqlWrite {
                    def execute(sql, params, k) = {
                        record(Statement.Execute(sql, params));
                        k(Ok(0))
                    }
                    def executeReturning(sql, params, k) = {
                        record(Statement.Execute(sql, params));
                        k(Ok(Nil))
                    }
                    def insertMany(sql, rows, k) = {
                        record(Statement.InsertMany(sql, rows));
                        k(Ok(List.length(rows)))
                    }
                    def commit(k) = {
                        record(Statement.Commit);
                        k(Ok())
                    }
                    def rollback(k) = {
                        record(Statement.Rollback);
                        k(Ok())
                    }
                }
            } with handler SqlRead {
                def fetch(sql, params, k) = {
                    record(Statement.Fetch(sql, params));
                    k(Err(DbError.unreachable("nothing was sent, so nothing can be read back")))
                }
            } with handler SqlSavepoint {
                def control(command, k) = {
                    record(Statement.Execute(Lite3fx.Savepoint.toSql(command), Nil));
                    k(Ok())
                }
            };
            (Lite3fx.Db.rethrowing(outcome), List.reverse(Ref.get(log)))
        }

}
