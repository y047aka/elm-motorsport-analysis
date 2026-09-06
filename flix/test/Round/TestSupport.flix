/// Loading laps as a round of their own, so that what a rule or a summary reads
/// back can be tested against laps written out by hand.
mod Round.TestSupport {

    use Db.Cars
    use Db.Laps

    use Db.CarRow
    use Db.Jdbc
    use Db.LapRow
    use Motorsport.Calendar.Entry
    use Motorsport.Wec.RawLap

    /// A database of its own per connection, so what a test loads is never the
    /// archive a working copy has.
    pub def url(): String = "jdbc:sqlite::memory:"

    pub def onRound(entry: Entry, laps: List[RawLap], read: Unit -> Result[Db.Error, a] \ DbRead): a \ IO =
        onRows(entry, laps, true, read)

    /// As `onRound`, with the round's cars left out: what a round only half in
    /// the database reads as.
    pub def onLapsAlone(entry: Entry, laps: List[RawLap], read: Unit -> Result[Db.Error, a] \ DbRead): a \ IO =
        onRows(entry, laps, false, read)

    def onRows(entry: Entry, laps: List[RawLap], withCars: Bool, read: Unit -> Result[Db.Error, a] \ DbRead): a \ IO =
        match Jdbc.connect(url()) {
            case Err(cause) => bug!("no database (${cause})")
            case Ok(conn) =>
                let result = Jdbc.runWith(conn, () -> forM(
                    _     <- Cars.create();
                    _     <- Laps.create();
                    _     <- if (withCars) Cars.insertRows(CarRow.fromRawLaps(entry, laps)) else Ok(0);
                    _     <- Laps.insertRows(LapRow.fromRawLaps(entry, laps));
                    value <- read()
                ) yield value);
                Jdbc.close(conn);
                match result {
                    case Ok(value)  => value
                    case Err(cause) => bug!("${cause}")
                }
        }

}
