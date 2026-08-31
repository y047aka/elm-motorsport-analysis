mod Cli.Db {

    use Cli.Db.LapRow.LapRow
    use Cli.Db.Schema

    /// Belongs before the first round: a schema this database will not take
    /// would otherwise be reported once per round, in the same words.
    pub def prepare(): Result[String, Unit] \ Db =
        forM(
            _ <- Cli.Db.execute(Schema.dropTable());
            _ <- Cli.Db.execute(Schema.createTable())
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
                // Reads nothing back: a caller that goes on to read what it
                // wrote needs a database, not this.
                def fetch(sql, k) = {
                    record(log, Statement.Fetch(sql));
                    k(Ok(Nil))
                }
            };
            (result, List.reverse(Ref.get(log)))
        }

    def record(log: Ref[List[Statement], r], statement: Statement): Unit \ r =
        Ref.put(statement :: Ref.get(log), log)

}
