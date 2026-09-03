/// Loading laps as a round of their own, so that what a rule or a summary reads
/// back can be tested against laps written out by hand.
///
/// The tests keep to a schema of their own: what they drop and rebuild is never
/// the archive a working copy has loaded.
mod Round.TestSupport {

    use Db.Jdbc
    use Db.LapRow
    use Motorsport.Calendar.Entry
    use Motorsport.Wec.RawLap

    pub def onRound(entry: Entry, laps: List[RawLap], read: Unit -> Result[String, a] \ Db): a \ IO =
        let url = Sys.Env.runWithIO(() -> Sys.Env.getVar("DATABASE_URL"))
            |> Option.getWithDefault("");
        match Jdbc.connect(url) {
            case Err(cause) => bug!("no database (${cause})")
            case Ok(conn) =>
                let result = Jdbc.runWith(conn, () -> forM(
                    _     <- Db.execute("CREATE SCHEMA IF NOT EXISTS cli_test");
                    _     <- Db.execute("SET search_path TO cli_test");
                    _     <- Db.prepare();
                    _     <- Db.insertLaps(LapRow.fromRawLaps(entry, laps));
                    value <- read()
                ) yield value);
                Jdbc.close(conn);
                match result {
                    case Ok(value)  => value
                    case Err(cause) => bug!(cause)
                }
        }

}
