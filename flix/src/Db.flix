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
pub eff Db {
    def execute(sql: String): Result[String, Unit]
    def insertMany(sql: String, rows: List[List[Db.Value]]): Result[String, Int32]
    def fetch(sql: String, params: List[Db.Value]): Result[String, List[List[Option[String]]]]
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

    /// What `runRecording` keeps.
    pub enum Statement {
        case Execute(String)
        case InsertMany(String, List[List[Value]])
        case Fetch(String, List[Value])
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
            };
            (result, List.reverse(Ref.get(log)))
        }

    def record(log: Ref[List[Statement], r], statement: Statement): Unit \ r =
        Ref.put(statement :: Ref.get(log), log)

}
