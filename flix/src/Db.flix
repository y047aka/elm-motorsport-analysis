use Db.LapRow.LapRow

/// Every write the run makes to a database.
///
/// `insertLaps` answers with the number of rows the database took rather
/// than with the number it was handed, so the run reports what was accepted
/// beside what it decoded.
///
/// `fetch` answers with every cell as text, `None` where the column was
/// null. The server has the types and the caller knows what it asked for,
/// so nothing is gained by carrying them across in between.
pub eff Db {
    def execute(sql: String): Result[String, Unit]
    def insertLaps(rows: List[LapRow]): Result[String, Int32]
    def fetch(sql: String): Result[String, List[List[Option[String]]]]
}

mod Db {

    use Db.LapRow.LapRow
    use Db.Schema

    /// Belongs before the first round: a schema this database will not take
    /// would otherwise be reported once per round, in the same words.
    pub def prepare(): Result[String, Unit] \ Db =
        forM(
            _ <- Db.execute(Schema.dropTable());
            _ <- Db.execute(Schema.createTable())
        ) yield ()

    /// What `runRecording` keeps.
    pub enum Statement {
        case Execute(String)
        case InsertLaps(List[LapRow])
        case Fetch(String)
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
                def insertLaps(rows, k) = {
                    record(log, Statement.InsertLaps(rows));
                    k(Ok(List.length(rows)))
                }
                // Nothing was written, so there is nothing to read back: a
                // caller that reads the round it sent needs a database, and
                // is told so rather than handed an empty one.
                def fetch(sql, k) = {
                    record(log, Statement.Fetch(sql));
                    k(Err("nothing was sent to a database, so nothing can be read back"))
                }
            };
            (result, List.reverse(Ref.get(log)))
        }

    def record(log: Ref[List[Statement], r], statement: Statement): Unit \ r =
        Ref.put(statement :: Ref.get(log), log)

}
