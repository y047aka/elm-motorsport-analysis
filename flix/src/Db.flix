/// Reaching a database, and nothing about what is in one: the effect names no
/// table and no column, so `Db.Jdbc` and `Db.runRecording` are the whole of
/// what a statement can be sent through.
///
/// `insertMany` binds each row to one statement and answers with the number
/// the database took rather than the number it was handed, so the run reports
/// what was accepted beside what it decoded.
///
/// `fetch` answers with every cell as text, `None` where the column was
/// null. The server has the types and the caller knows what it asked for,
/// so nothing is gained by carrying them across in between.
///
/// Nothing a statement sends is kept until `commit`, which is what `Db.transact`
/// is for: a caller that sends and never commits has sent nothing.
pub eff Db {
    def execute(sql: String): Result[String, Unit]
    def insertMany(sql: String, rows: List[List[Db.Value]]): Result[String, Int32]
    def fetch(sql: String, params: List[Db.Value]): Result[String, List[List[Option[String]]]]
    def commit(): Result[String, Unit]
    def rollback(): Result[String, Unit]
}

mod Db {

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
    pub def transact(f: Unit -> Result[String, a] \ ef): Result[String, a] \ ef + Db =
        match f() {
            case Ok(value) => Db.commit() |> Result.map(_ -> value)
            case Err(e)    => discard Db.rollback(); Err(e)
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
                f()
            } with handler Db {
                def execute(sql, k) = {
                    record(log, Statement.Execute(sql));
                    k(Ok())
                }
                def insertMany(sql, rows, k) = {
                    record(log, Statement.InsertMany(sql, rows));
                    k(Ok(List.length(rows)))
                }
                // Nothing was written, so there is nothing to read back: a
                // caller that reads the round it sent needs a database, and
                // is told so rather than handed an empty one.
                def fetch(sql, params, k) = {
                    record(log, Statement.Fetch(sql, params));
                    k(Err("nothing was sent to a database, so nothing can be read back"))
                }
                def commit(k) = {
                    record(log, Statement.Commit);
                    k(Ok())
                }
                def rollback(k) = {
                    record(log, Statement.Rollback);
                    k(Ok())
                }
            };
            (result, List.reverse(Ref.get(log)))
        }

    def record(log: Ref[List[Statement], r], statement: Statement): Unit \ r =
        Ref.put(statement :: Ref.get(log), log)

}
