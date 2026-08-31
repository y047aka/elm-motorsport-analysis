mod Cli {

    use Cli.Db.LapRow.LapRow

    /// Every write the run makes to a database.
    ///
    /// `insertLaps` answers with the number of rows written rather than with the
    /// number it was given, because a run that reached no database returns zero
    /// here and that is the only thing telling the two runs apart.
    eff Db {
        def execute(sql: String): Result[String, Unit]
        def insertLaps(rows: List[LapRow]): Result[String, Int32]
    }

}
