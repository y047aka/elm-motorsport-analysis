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
    }

    /// The handler for a run given no `--postgres` URL.
    pub def runDiscarding(f: Unit -> a \ ef): a \ (ef - Db) =
        run {
            f()
        } with handler Db {
            def execute(_sql, k) = k(Ok())
            def insertLaps(_rows, k) = k(Ok(0))
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
            };
            (result, List.reverse(Ref.get(log)))
        }

    def record(log: Ref[List[Statement], r], statement: Statement): Unit \ r =
        Ref.put(statement :: Ref.get(log), log)

}
