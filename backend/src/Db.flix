/// Reaching a database, and nothing about what is in one: the effects name no
/// table and no column, so `Db.Jdbc` and `Db.runRecording` are the whole of
/// what a statement can be sent through.
///
/// `fetch` answers with every cell as text, `None` where the column was
/// null. The server has the types and the caller knows what it asked for,
/// so nothing is gained by carrying them across in between.
pub eff SqlRead {
    def fetch(sql: String, params: List[Db.Value]): Result[Db.Error, List[List[Option[String]]]]
}

/// `insertMany` binds each row to one statement and answers with the number
/// the database took rather than the number it was handed, so the run reports
/// what was accepted beside what it decoded.
///
/// Nothing a statement sends is kept until `commit`, which is what `Db.transact`
/// is for: a caller that sends and never commits has sent nothing.
pub eff SqlWrite {
    def execute(sql: String): Result[Db.Error, Unit]
    def insertMany(sql: String, rows: List[List[Db.Value]]): Result[Db.Error, Int32]
    def commit(): Result[Db.Error, Unit]
    def rollback(): Result[Db.Error, Unit]
}

/// What ends the reading it happened in. `raise` does not return, so a
/// function reaching the database answers with what it read and not with
/// whether it could: the failure travels to `Db.attempt` on its own.
///
/// The two effects above answer with a `Result` because a Flix handler body is
/// evaluated outside the `run` it belongs to, so a failure raised in one would
/// pass every handler the caller had installed. `Db.orRaise` is where the
/// value becomes this, in the caller's own context.
///
/// One operation rather than one per kind, so that a kind added to `Db.Error`
/// breaks the code that matches on it and not every handler ever installed.
pub eff DbErr {
    def raise(error: Db.Error): Void
}

/// The failures that trying the same thing again may get past, which is the
/// line between a round that cannot be served now and one that cannot be
/// served at all.
///
/// Apart from `DbErr` rather than one case inside it because a caller that
/// wants to try again -- and only such a caller -- installs this one and lets
/// the rest through.
pub eff TransientDbErr {
    def raise(error: Db.Error): Void
}

/// The savepoints a reading marks.
///
/// One command rather than one operation per statement, so that a fourth one
/// breaks the code that matches on it and not every handler ever installed.
pub eff SqlSavepoint {
    def control(command: Db.Savepoint.Command): Result[Db.Error, Unit]
}

/// What a signature says, which is a statement and both of its failings.
pub type alias DbRead = {SqlRead, TransientDbErr, DbErr}
pub type alias DbWrite = {SqlWrite, TransientDbErr, DbErr}
pub type alias Db = {SqlRead, SqlWrite, SqlSavepoint, TransientDbErr, DbErr}

pub mod Db {

    import java.lang.StackOverflowError
    import java.lang.Throwable
    import java.lang.VirtualMachineError

    /// What did not happen, rather than the sentence saying so, which is
    /// `ToString`'s.
    pub enum Error with Eq {
        /// A failure the same statement sent again may get past.
        case Transient(Transient)

        /// The database refused what it was sent, in the words the driver
        /// used.
        case Refused(String)

        /// A cell came back that the reading could not read.
        case Unread(String)

        /// A query that had to answer with a row answered with none.
        case NoRow(String)

        /// The rows came back whole and do not describe a round: a car with
        /// laps and no row in `cars` is the one this is for.
        case Incomplete(String)

        /// None of the others: what the driver threw rather than said, in
        /// whatever words the thing that threw had.
        case Other(String)
    }

    /// The failures that trying again is worth trying, which is the line
    /// between a round that cannot be served now and one that cannot be served.
    ///
    /// Apart from the rest rather than one case beside them, so that which of
    /// the two effects a failure travels by is read off its constructor: a kind
    /// added to either side meets a pattern that has to say which it is.
    pub enum Transient with Eq {
        /// No database was reached at all.
        case Unreachable(String)

        /// A lock the database waited out rather than got: the one refusal
        /// that says the same statement may go through next time.
        case Busy(String)
    }

    instance ToString[Error] {
        pub def toString(e: Error): String = match e {
            case Error.Transient(t)        => "${t}"
            case Error.Refused(cause)      => cause
            case Error.Unread(detail)      => detail
            case Error.NoRow(subject)      => "${subject} came back with no row"
            case Error.Incomplete(detail)  => detail
            case Error.Other(detail)       => detail
        }
    }

    instance ToString[Transient] {
        pub def toString(t: Transient): String = match t {
            case Transient.Unreachable(cause) => "no database (${cause})"
            case Transient.Busy(cause)        => cause
        }
    }

    /// No database was reached at all.
    pub def unreachable(cause: String): Error =
        Error.Transient(Transient.Unreachable(cause))

    /// A lock the database waited out rather than got.
    pub def busy(cause: String): Error =
        Error.Transient(Transient.Busy(cause))

    /// The two failings in one value, which is what a boundary takes back.
    /// Nothing between a boundary and the statement answers with this: the
    /// failure travels by an effect, and the three places a value comes back to
    /// -- a round of the export, a request, the run's own transaction -- read it.
    pub enum Failure with Eq {
        /// Trying the same thing again may get past it.
        case Transient(Transient)

        /// Trying the same thing again reaches the same failure.
        case Permanent(Error)
    }

    instance ToString[Failure] {
        pub def toString(f: Failure): String = match f {
            case Failure.Transient(t)     => "${t}"
            case Failure.Permanent(error) => "${error}"
        }
    }

    /// The failure, out of whichever effect carried it.
    pub def toFailure(error: Error): Failure = match error {
        case Error.Transient(t) => Failure.Transient(t)
        case _                  => Failure.Permanent(error)
    }

    /// The failure, as the effect it belongs to.
    pub def raiseFailure(failure: Failure): a \ {TransientDbErr, DbErr} = match failure {
        case Failure.Transient(t)     => TransientDbErr.raise(Error.Transient(t))
        case Failure.Permanent(error) => raise(error)
    }

    /// A value a `?` binds, or a cell came back as, in the type the driver
    /// answered in.
    ///
    /// SQLite's typing is per value rather than per column, so a cell is what
    /// the driver found and not what the schema declared: a reading takes what
    /// it can and says what it wanted in the failure it answers with.
    pub enum Value with Eq, ToString {
        case Text(String)
        case Integer(Int32)
        case Real(Float64)
        case Boolean(Bool)
        /// The mini-sector shares, in the JSON array the column holds.
        case Json(List[Option[Int32]])
        /// Nothing, and the SQL type the driver is told to read it as.
        case Null(NullType)
    }

    /// The type a `null` is bound as, which is what JDBC's `setNull` asks for.
    pub enum NullType with Eq, ToString {
        case Text
        case Integer
    }

    /// A value that may be absent, which is what a nullable column binds.
    pub def ofNull(option: Option[Value], nullType: NullType): Value =
        match option {
            case Some(value) => value
            case None        => Value.Null(nullType)
        }

    /// Whether trying the same statement again is worth trying, which the
    /// constructor says.
    pub def isTransient(error: Error): Bool = match error {
        case Error.Transient(_) => true
        case _                  => false
    }

    /// The failure, as whichever of the two effects carries it.
    pub def raise(error: Error): a \ {TransientDbErr, DbErr} =
        if (isTransient(error)) TransientDbErr.raise(error) else DbErr.raise(error)

    /// The text a nullable-int-array column holds, which `json_each` reads
    /// back as one row per element.
    pub def jsonArray(values: List[Option[Int32]]): String =
        "[" + (values |> List.map(v -> match v {
            case Some(n) => "${n}"
            case None    => "null"
        }) |> List.join(",")) + "]"

    /// The value, or the failure that ended the reading.
    pub def runWithError(f: Unit -> a \ ef): Result[Error, a] \ (ef - {TransientDbErr, DbErr}) =
        let outcome = run {
                run {
                    Ok(catchAll(f))
                } with handler DbErr {
                    def raise(error, _k) = Err(error)
                }
            } with handler TransientDbErr {
                def raise(error, _k) = Err(error)
            };
        Result.map(rethrowing, outcome)

    /// The failure, whichever of the two effects carried it. This is where a
    /// reading stops being a value and starts being a `Result`.
    pub def attempt(f: Unit -> a \ ef): Result[Failure, a] \ (ef - {TransientDbErr, DbErr}) =
        runWithError(f) |> Result.mapErr(toFailure)

    // --------------------------------------------------- what the JVM throws

    /// `f` run, and whatever it threw kept as a value -- the same throwable,
    /// untouched. Whether it was a database's failure or the JVM's is the
    /// caller's to decide, and a fatal one is not a failure to keep.
    ///
    /// The handlers installed here are wrapped with this, and the throw comes
    /// back after the `run` has been left: what is thrown from inside a `run`
    /// passes every catch the caller had put outside it.
    pub def catchAll(f: Unit -> a \ ef): Result[Throwable, a] \ ef =
        try {
            Ok(f())
        } catch {
            case error: Throwable => Err(error)
        }

    /// A throwable kept as a value thrown again -- the same one, not a copy of
    /// it and not wrapped in another.
    ///
    /// The throwing is not in the signature: what comes out is what the caller
    /// already threw and not a new side effect, and writing it would put `IO`
    /// on every entry that takes a failure as a value.
    pub def rethrowing(outcome: Result[Throwable, a]): a = match outcome {
        case Ok(value)  => value
        case Err(error) => unchecked_cast(throwAgain(error) as _ \ {})
    }

    def throwAgain(error: Throwable): a \ IO = throw error

    /// Something the JVM cannot go on past. The cause chain is walked because a
    /// driver or a future can wrap an `OutOfMemoryError` in something that is
    /// not fatal to look at from the outside.
    pub def isFatal(error: Throwable): Bool \ IO =
        isFatalWithin(error, 0)

    /// How far down to look before concluding the chain has no fatal end: a
    /// throwable that carries itself as its own cause has to stop somewhere.
    def maxCauseDepth(): Int32 = 8

    def isFatalWithin(error: Throwable, depth: Int32): Bool \ IO =
        if (isFatalItself(error)) true
        else {
            let cause = error.getCause();
            if (Object.isNull(cause) or depth >= maxCauseDepth()) false
            else isFatalWithin(cause, depth + 1)
        }

    /// `StackOverflowError` is a `VirtualMachineError` and is not fatal here:
    /// one reading recursing too deeply is a failure its caller can be taken
    /// back from, and the JVM goes on.
    ///
    /// Thrown and caught rather than tested, since Flix has no type predicate
    /// and a `catch` puts a subclass ahead of the one under it.
    def isFatalItself(error: Throwable): Bool \ IO =
        try {
            throw error
        } catch {
            case _: StackOverflowError  => false
            case _: VirtualMachineError => true
            case _: Throwable           => false
        }

    /// What a throwable says. Some of what the driver throws says nothing, and
    /// `null` is not a sentence to put in a failure.
    pub def describeThrowable(error: Throwable): String \ IO =
        let message: String = error.getMessage();
        if (Object.isNull(message)) error.getClass().getName() else message

    /// What the JVM threw, as a failure of the database. A failure the JVM
    /// cannot go on past is thrown again rather than turned into a value.
    ///
    /// The driver is reached through interop and the exceptions it throws are
    /// not all `SQLException`; without this one escapes every handler the
    /// caller had installed, which is the same reason the statement effects
    /// answer with a `Result`.
    pub def guard(f: Unit -> a \ ef): a \ ef + IO + DbErr =
        match catchAll(f) {
            case Ok(value)  => value
            case Err(error) =>
                if (isFatal(error)) rethrowing(Err(error))
                else DbErr.raise(Error.Other(describeThrowable(error)))
        }

    /// What a statement answered, as the value it read or as a failure of the
    /// caller's own.
    pub def orRaise(result: Result[Error, a]): a \ {TransientDbErr, DbErr} =
        match result {
            case Ok(value) => value
            case Err(e)    => raise(e)
        }

    // ------------------------------------------------------- the statements

    /// What a caller sends rather than the operations themselves, which no
    /// module outside this one calls: the failure a handler answered with
    /// becomes a `DbErr` here, where the caller's own handlers are installed.

    pub def fetch(sql: String, params: List[Value]): List[List[Option[String]]] \ DbRead =
        SqlRead.fetch(sql, params) |> orRaise

    pub def execute(sql: String): Unit \ DbWrite =
        SqlWrite.execute(sql) |> orRaise

    pub def insertMany(sql: String, rows: List[List[Value]]): Int32 \ DbWrite =
        SqlWrite.insertMany(sql, rows) |> orRaise

    def commit(): Unit \ DbWrite =
        SqlWrite.commit() |> orRaise

    /// What `transact` takes back with, which says nothing the failure it is
    /// undoing does not.
    def rollback(): Unit \ SqlWrite =
        discard SqlWrite.rollback()

    /// The statements `f` sends, kept or discarded together: they land when it
    /// returns and are undone when a failure ends it, which is then raised
    /// again.
    ///
    /// A run that dies before answering commits nothing, which is what makes a
    /// rebuild of the table safe to interrupt: the `DROP TABLE` it starts with
    /// is undone with the rows it did not finish loading.
    pub def transact(f: Unit -> a \ ef): a \ (ef - {TransientDbErr, DbErr}) + DbWrite =
        match runWithError(f) {
            case Ok(value) => commit(); value
            case Err(e)    => rollback(); raise(e)
        }

    /// As `transact`, of a part of one: the statements `f` sends are undone
    /// together when a failure ends it, and what its caller sent before is
    /// still to be committed.
    ///
    /// A name the database would not take is `Error.Other`, and a failure
    /// inside the mark comes back as a value rather than raised.
    ///
    /// The savepoint is SQLite's rather than the driver's, so it goes out as a
    /// statement -- which is what `runRecording` keeps and `runFailing` refuses,
    /// like every other. `Db.Jdbc` marks one of the driver's per insert, and
    /// that is the batch's alone.
    pub def withSavepoint(name: String, f: Unit -> a \ ef): Result[Failure, a] \ (ef - {TransientDbErr, DbErr}) + {SqlSavepoint, TransientDbErr, DbErr} =
        if (not Savepoint.isValidName(name))
            Err(Failure.Permanent(Error.Other("not a savepoint name: ${name} (${Savepoint.nameRule()})")))
        else {
            control(Savepoint.Command.Mark(name));
            match attempt(f) {
                case Ok(value) => { control(Savepoint.Command.Release(name)); Ok(value) }
                case Err(e)    => {
                    control(Savepoint.Command.BackTo(name));
                    control(Savepoint.Command.Release(name));
                    Err(e)
                }
            }
        }

    /// The statement, and the failure it answered with raised in the caller's
    /// own context.
    def control(command: Savepoint.Command): Unit \ {SqlSavepoint, TransientDbErr, DbErr} =
        orRaise(SqlSavepoint.control(command))

    /// What `runRecording` keeps.
    pub enum Statement with Eq {
        case Execute(String)
        case InsertMany(String, List[List[Value]])
        case Fetch(String, List[Value])
        case Commit
        case Rollback
    }

    pub def runRecording(f: Unit -> a \ ef): (a, List[Statement]) \ (ef - {SqlRead, SqlWrite, SqlSavepoint}) =
        region rc {
            let log = Ref.fresh(rc, (Nil: List[Statement]));
            let result = run {
                run {
                    catchAll(f)
                } with handler SqlWrite {
                    def execute(sql, k) = {
                        record(log, Statement.Execute(sql));
                        k(Ok())
                    }
                    def insertMany(sql, rows, k) = {
                        record(log, Statement.InsertMany(sql, rows));
                        k(Ok(List.length(rows)))
                    }
                    def commit(k) = {
                        record(log, Statement.Commit);
                        k(Ok())
                    }
                    def rollback(k) = {
                        record(log, Statement.Rollback);
                        k(Ok())
                    }
                }
            } with handler SqlRead {
                // Nothing was written, so there is nothing to read back: a
                // caller that reads the round it sent needs a database, and
                // is told so rather than handed an empty one.
                def fetch(sql, params, k) = {
                    record(log, Statement.Fetch(sql, params));
                    k(Err(unreachable("nothing was sent, so nothing can be read back")))
                }
            } with handler SqlSavepoint {
                def control(command, k) = {
                    record(log, Statement.Execute(Savepoint.toSql(command)));
                    k(Ok())
                }
            };
            (rethrowing(result), List.reverse(Ref.get(log)))
        }

    /// A database that answers every statement with the same failure, for a
    /// caller whose subject is what it does about one.
    pub def runFailing(error: Error, f: Unit -> a \ ef): a \ (ef - {SqlRead, SqlWrite, SqlSavepoint}) =
        let outcome = run {
            run {
                catchAll(f)
            } with handler SqlWrite {
                def execute(_sql, k) = k(Err(error))
                def insertMany(_sql, _rows, k) = k(Err(error))
                def commit(k) = k(Err(error))
                def rollback(k) = k(Err(error))
            }
        } with handler SqlRead {
            def fetch(_sql, _params, k) = k(Err(error))
        } with handler SqlSavepoint {
            def control(_command, k) = k(Err(error))
        };
        rethrowing(outcome)

    def record(log: Ref[List[Statement], r], statement: Statement): Unit \ r =
        Ref.put(statement :: Ref.get(log), log)

}
