/// Reaching a database, and nothing about what is in one: the effects name no
/// table and no column, so `Lite3fx.Jdbc` and `Lite3fx.Recording.statements` are
/// the whole of what a statement can be sent through.
///
/// The effects, their aliases, and the failure an op carries are sqlfx's, over
/// `org.xerial:sqlite-jdbc`.
pub mod Lite3fx {

    use Lite3fx.DbError.DbErrorKind
    use Lite3fx.Row.Row
    use Lite3fx.Savepoint
    use Lite3fx.SqlValue.SqlValue

    /// Issues a `SELECT` and answers with every row of it. A cell is the type
    /// the driver found it in rather than the column's own: SQLite types a
    /// value, not a column.
    ///
    /// The op answers with a `Result` because a Flix handler body is evaluated
    /// outside the `run` it belongs to, so a failure raised in one would pass
    /// every handler the caller had installed. `Lite3fx.Sql.orRaise` is where the
    /// value becomes a raised failure, in the caller's own context.
    pub eff SqlRead {
        /// The statement, its placeholder's values, and every row that came back.
        def fetch(sql: String, params: List[SqlValue]): Result[DbErrorKind, List[Row]]
    }

    /// `execute` answers with the number of rows the database took rather than
    /// the number it was sent, and `insertMany` binds each row to one statement
    /// and answers the same way.
    ///
    /// Nothing a statement sends is kept until `commit`, which is what
    /// `Lite3fx.Tx.transact` is for: a caller that sends and never commits has
    /// sent nothing.
    pub eff SqlWrite {
        def execute(sql: String, params: List[SqlValue]): Result[DbErrorKind, Int32]
        /// A statement written `RETURNING`, which answers with rows as a `SELECT` does.
        def executeReturning(sql: String, params: List[SqlValue]): Result[DbErrorKind, List[Row]]
        def insertMany(sql: String, rows: List[List[SqlValue]]): Result[DbErrorKind, Int32]
        def commit(): Result[DbErrorKind, Unit]
        def rollback(): Result[DbErrorKind, Unit]
    }

    /// The failures that trying the same thing again may get past, which is the
    /// line between a round that cannot be served now and one that cannot be
    /// served at all.
    ///
    /// Apart from `DbErr` rather than one case inside it because a caller that
    /// wants to try again -- and only such a caller -- installs this one and lets
    /// the rest through.
    ///
    /// One operation rather than one per kind, so that a kind added to either
    /// enum breaks the code that matches on it and not every handler ever
    /// installed.
    pub eff TransientDbErr {
        def raise(kind: DbErrorKind): Void
    }

    /// Failed, and running it again will not help. `raise` does not return, so a
    /// function reaching the database answers with what it read and not with
    /// whether it could: the failure travels by itself to the boundary that
    /// asked.
    pub eff DbErr {
        def raise(kind: DbErrorKind): Void
    }

    /// The savepoints a reading marks.
    ///
    /// One command rather than one operation per statement, so that a fourth one
    /// breaks the code that matches on it and not every handler ever installed.
    pub eff SqlSavepoint {
        def control(command: Savepoint.Command): Result[DbErrorKind, Unit]
    }

    /// Whether a statement's text was written rather than built.
    ///
    /// A marker, not a check: it names the functions that put SQL on the wire, so
    /// the ones taking text from further away are enumerable from the signatures
    /// rather than from a search. `runWithAllow` goes over the boundaries that
    /// have read what they send.
    pub eff RawSql {
        /// The statement about to be sent.
        def allow(sql: String): Unit
    }

    /// What a signature says, which is a statement, both of its failings, and the
    /// marker saying its text was written. A caller naming one of these is already
    /// saying a statement goes out, which is what the marker is for.
    pub type alias DbRead = {SqlRead, TransientDbErr, DbErr, RawSql}
    pub type alias DbWrite = {SqlWrite, TransientDbErr, DbErr, RawSql}
    pub type alias Db = {SqlRead, SqlWrite, SqlSavepoint, TransientDbErr, DbErr, RawSql}

}
