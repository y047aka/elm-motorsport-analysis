mod Cli {

    use Cli.Db.LapRow.LapRow

    /// Every write the run makes to a database.
    ///
    /// `insertLaps` answers with the number of rows written rather than with the
    /// number it was given, because a run that reached no database returns zero
    /// here and that is the only thing telling the two runs apart.
    ///
    /// `fetch` answers with every cell as text, `None` where the column was
    /// null. The server has the types and the caller knows what it asked for,
    /// so nothing is gained by carrying them across in between.
    eff Db {
        def execute(sql: String): Result[String, Unit]
        def insertLaps(rows: List[LapRow]): Result[String, Int32]
        def fetch(sql: String): Result[String, List[List[Option[String]]]]
    }

}
