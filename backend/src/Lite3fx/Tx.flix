/// The transaction, and the parts of one that come back on their own.
pub mod Lite3fx.Tx {

    use Lite3fx.DbErr
    use Lite3fx.DbError
    use Lite3fx.DbError.DbErrorKind
    use Lite3fx.DbError.Failure
    use Lite3fx.Savepoint
    use Lite3fx.Sql.orRaise
    use Lite3fx.SqlSavepoint
    use Lite3fx.SqlWrite
    use Lite3fx.TransientDbErr

    /// The statements `f` sends, kept or discarded together: they land when it
    /// returns and are undone when a failure ends it, which is then raised
    /// again.
    ///
    /// A run that dies before answering commits nothing, which is what makes a
    /// rebuild of the table safe to interrupt: the `DROP TABLE` it starts with is
    /// undone with the rows it did not finish loading.
    pub def transact(f: Unit -> a \ ef): a \ (ef - {TransientDbErr, DbErr}) + {SqlWrite, TransientDbErr, DbErr} =
        match DbError.runWithKind(f) {
            case Ok(value) => { commit(); value }
            case Err(e)    => { rollback(); DbError.raise(e) }
        }

    /// As `transact`, of a part of one: the statements `f` sends are undone
    /// together when a failure ends it, and what its caller sent before is still
    /// to be committed.
    ///
    /// A name the database would not take is `DbErrorKind.Other`, and a failure
    /// inside the mark comes back as a value rather than raised.
    ///
    /// The savepoint is released after being rolled back to rather than left
    /// marked: `ROLLBACK TO` leaves it there, and a caller that marks the same
    /// name again -- `Lite3fx.Retry.retryingSavepoint` does, once per try --
    /// would nest one level each.
    ///
    /// The savepoint is SQLite's rather than the driver's, so it goes out as a
    /// statement -- which is what `DbTest.runRecording` keeps and
    /// `DbTest.runFailing` refuses, like every other. `Lite3fx.Jdbc` marks one of
    /// the driver's per insert, and that one is the batch's alone.
    pub def withSavepoint(name: String, f: Unit -> a \ ef): Result[Failure, a] \ (ef - {TransientDbErr, DbErr}) + {SqlSavepoint, TransientDbErr, DbErr} =
        if (not Savepoint.isValidName(name))
            Err(Failure.Permanent(DbErrorKind.Other("not a savepoint name: ${name} (${Savepoint.nameRule()})")))
        else {
            control(Savepoint.Command.Mark(name));
            match DbError.runWithFailure(f) {
                case Ok(value) => { control(Savepoint.Command.Release(name)); Ok(value) }
                case Err(e)    => {
                    control(Savepoint.Command.RollbackTo(name));
                    control(Savepoint.Command.Release(name));
                    Err(e)
                }
            }
        }

    /// The statement, and the failure it answered with raised in the caller's own
    /// context.
    def control(command: Savepoint.Command): Unit \ {SqlSavepoint, TransientDbErr, DbErr} =
        orRaise(SqlSavepoint.control(command))

    def commit(): Unit \ {SqlWrite, TransientDbErr, DbErr} =
        SqlWrite.commit() |> orRaise

    /// What `transact` takes back with, which says nothing the failure it is
    /// undoing does not.
    def rollback(): Unit \ SqlWrite =
        discard SqlWrite.rollback()

}
