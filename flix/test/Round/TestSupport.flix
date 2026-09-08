/// Loading laps as a round of their own, so that what a rule or a summary reads
/// back can be tested against laps written out by hand.
mod Round.TestSupport {

    use Db.CarDrivers
    use Db.Cars
    use Db.Drivers
    use Db.Laps
    use Db.Rounds

    use Db.CarRow
    use Db.Jdbc
    use Db.LapRow
    use Motorsport.Calendar.Entry
    use Motorsport.Wec.RawLap

    /// A database of its own per connection, so what a test loads is never the
    /// archive a working copy has.
    pub def url(): String = "jdbc:sqlite::memory:"

    pub def onRound(entry: Entry, laps: List[RawLap], read: Unit -> a \ ef): a \ (ef - {SqlRead, SqlWrite, DbErr}) + IO =
        onRows(entry, laps, true, read)

    /// As `onRound`, with the round's cars left out: what a round only half in
    /// the database reads as.
    pub def onLapsAlone(entry: Entry, laps: List[RawLap], read: Unit -> a \ ef): a \ (ef - {SqlRead, SqlWrite, DbErr}) + IO =
        onRows(entry, laps, false, read)

    def onRows(entry: Entry, laps: List[RawLap], withCars: Bool, read: Unit -> a \ ef): a \ (ef - {SqlRead, SqlWrite, DbErr}) + IO =
        let outcome = Db.runWithError(() -> Jdbc.withConnection(url(), () -> {
            let rounds = Rounds.create(entry :: Nil);
            Drivers.create();
            CarDrivers.create();
            Cars.create();
            Laps.create();
            let roundId = match Rounds.idIn(rounds, entry) {
                case Some(id) => id
                case None     => bug!("the round just written has no row")
            };
            let seats = CarDrivers.seats(laps);
            let (numbering, drivers) = Drivers.add(Drivers.noneNumbered(), seats |> List.map(s -> s#name));
            discard Drivers.insertRows(drivers);
            match CarDrivers.fromSeats(roundId, numbering, seats) {
                case Some(rows) => discard CarDrivers.insertRows(rows)
                case None       => bug!("a seat the run just numbered has no id")
            };
            if (withCars) discard Cars.insertRows(CarRow.fromRawLaps(roundId, laps)) else ();
            discard Laps.insertRows(LapRow.fromRawLaps(roundId, laps));
            read()
        }));
        match outcome {
            case Ok(value)  => value
            case Err(cause) => bug!("${cause}")
        }

}
