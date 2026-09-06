/// Reaching a database, and nothing about what is in one: the effects name no
/// table and no column, so `Db.Jdbc` and `Db.runRecording` are the whole of
/// what a statement can be sent through.
///
/// `fetch` answers with every cell as text, `None` where the column was
/// null. The server has the types and the caller knows what it asked for,
/// so nothing is gained by carrying them across in between.
pub eff DbRead {
    def fetch(sql: String, params: List[Db.Value]): Result[Db.Error, List[List[Option[String]]]]
}

/// `insertMany` binds each row to one statement and answers with the number
/// the database took rather than the number it was handed, so the run reports
/// what was accepted beside what it decoded.
///
/// Nothing a statement sends is kept until `commit`, which is what `Db.transact`
/// is for: a caller that sends and never commits has sent nothing.
pub eff DbWrite {
    def execute(sql: String): Result[Db.Error, Unit]
    def insertMany(sql: String, rows: List[List[Db.Value]]): Result[Db.Error, Int32]
    def commit(): Result[Db.Error, Unit]
    def rollback(): Result[Db.Error, Unit]
}

/// Both halves, for a caller that does reach the database either way.
pub type alias Db = {DbRead, DbWrite}

mod Db {

    /// What did not happen, rather than the sentence saying so, which is
    /// `ToString`'s.
    pub enum Error with Eq {
        /// No database was reached at all.
        case Unreachable(String)

        /// The database refused what it was sent, in the words the driver
        /// used.
        case Refused(String)

        /// A lock the database waited out rather than got: the one refusal
        /// that says the same statement may go through next time.
        case Busy(String)

        /// A cell came back that the reading could not read.
        case Unread(String)

        /// A query that had to answer with a row answered with none.
        case NoRow(String)

        /// The rows came back whole and do not describe a round: a car with
        /// laps and no row in `cars` is the one this is for.
        case Incomplete(String)
    }

    instance ToString[Error] {
        pub def toString(e: Error): String = match e {
            case Error.Unreachable(cause)  => "no database (${cause})"
            case Error.Refused(cause)      => cause
            case Error.Busy(cause)         => cause
            case Error.Unread(detail)      => detail
            case Error.NoRow(subject)      => "${subject} came back with no row"
            case Error.Incomplete(detail)  => detail
        }
    }

    /// A value bound to a `?`, in the type its column or comparison has.
    pub enum Value with Eq, ToString {
        case Text(String)
        case Integer(Int32)
        case Boolean(Bool)
        case NullableInteger(Option[Int32])
        case NullableIntArray(Option[List[Option[Int32]]])
    }

    /// The text a nullable-int-array column holds, which `json_each` reads
    /// back as one row per element.
    pub def jsonArray(values: List[Option[Int32]]): String =
        "[" + (values |> List.map(v -> match v {
            case Some(n) => "${n}"
            case None    => "null"
        }) |> List.join(",")) + "]"

    /// The statements `f` sends, kept or discarded together: they land when it
    /// answers `Ok` and are undone when it does not.
    ///
    /// A run that dies before answering commits nothing, which is what makes a
    /// rebuild of the table safe to interrupt: the `DROP TABLE` it starts with
    /// is undone with the rows it did not finish loading.
    pub def transact(f: Unit -> Result[Error, a] \ ef): Result[Error, a] \ ef + DbWrite =
        match f() {
            case Ok(value) => DbWrite.commit() |> Result.map(_ -> value)
            case Err(e)    => discard DbWrite.rollback(); Err(e)
        }

    /// What `runRecording` keeps.
    pub enum Statement {
        case Execute(String)
        case InsertMany(String, List[List[Value]])
        case Fetch(String, List[Value])
        case Commit
        case Rollback
    }

    pub def runRecording(f: Unit -> a \ ef): (a, List[Statement]) \ (ef - Db) =
        region rc {
            let log = Ref.fresh(rc, (Nil: List[Statement]));
            let result = run {
                run {
                    f()
                } with handler DbWrite {
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
            } with handler DbRead {
                // Nothing was written, so there is nothing to read back: a
                // caller that reads the round it sent needs a database, and
                // is told so rather than handed an empty one.
                def fetch(sql, params, k) = {
                    record(log, Statement.Fetch(sql, params));
                    k(Err(Error.Unreachable("nothing was sent, so nothing can be read back")))
                }
            };
            (result, List.reverse(Ref.get(log)))
        }

    def record(log: Ref[List[Statement], r], statement: Statement): Unit \ r =
        Ref.put(statement :: Ref.get(log), log)

}
