/// The round's summary, read back out of the rows it was just loaded into.
/// What is decided here is only what the feed does not say outright -- the
/// grid order, the time limit, the shape of the circuit -- and each of those
/// decisions stays in `Motorsport`: this reads, and hands over.
pub mod Round.Summary {

    use Db.Cars
    use Db.Entries
    use Db.Laps
    use Db.Rounds
    use Db.Schema
    use Sql.Sel
    use Motorsport.Calendar.Entry
    use Motorsport.Car.Car
    use Motorsport.Events
    use Motorsport.Metadata
    use Motorsport.Metadata.CarBuild
    use Motorsport.MiniSector
    use Motorsport.Sector.Sector
    use Motorsport.Track
    use Util.Duration.Duration
    use Util.HourClock.Hour

    pub def read(entry: Entry, seats: Round.Drivers.Seats): Metadata.Metadata \ DbRead =
        let race = particulars(entry);
        let shape = track(entry);
        Metadata.fromReadings(entry, race, shape, cars(entry, seats))

    // ---------------------------------------------------------- particulars

    /// `pub` reaches the load, which wants the time limit and not the grid.
    pub def particulars(entry: Entry): Metadata.Particulars \ DbRead =
        let start = startedAt(entry);
        let c = Laps.columns();
        Laps.rows(entry)
            |> Sql.map(_ -> (
                start,
                Sql.opt(Sql.max(c#elapsedMs)),
                Sql.opt(Sql.max(c#lapNumber))
            ))
            |> Sql.reading(match (started, duration, lapTotal) -> Metadata.particulars(
                Option.map(ms -> Hour.Hour(ms), started),
                Util.Duration.fromMillis(Option.getWithDefault(0, duration)),
                Option.getWithDefault(0, lapTotal)
            ))
            |> Sql.selectOne("the round's particulars")

    /// The round's start time, which is the offset the file's first lap
    /// carries.
    def startedAt(entry: Entry): Sel[Option[Int32]] \ DbErr =
        Sql.optionalIntOf(Sql.spliced(
            "(SELECT ${Schema.nameOf(Laps.hourOffsetMs())}"
                + " FROM ${Laps.table()} WHERE ?? ORDER BY source_row LIMIT 1)",
            Laps.scope(entry, Nil) :: Nil))

    // ----------------------------------------------------------------- cars

    def cars(entry: Entry, seats: Round.Drivers.Seats): List[CarBuild] \ DbRead =
        carBuilds(entry, driverNames(entry, seats))

    /// `(car number, driver name)` in the order the file first showed each
    /// seat, which is the order a car's drivers are listed in. The order is
    /// the laps' and the name is `car_drivers`', so the reading is of the one
    /// and the naming of the other.
    def driverNames(entry: Entry, seats: Round.Drivers.Seats): List[(String, String)] \ DbRead =
        let c = Laps.columns();
        Sql.statement(
            "SELECT %% FROM (SELECT car_number, driver_number, MIN(source_row) AS first_seen"
                + " FROM ${Laps.table()} WHERE ?? GROUP BY car_number, driver_number) d"
                + " ORDER BY first_seen",
            Laps.scope(entry, Nil) :: Nil,
            (c#carNumber, c#driverNumber))
            |> Sql.selectAll
            |> List.map(match (carNumber, driverNumber) ->
                (carNumber, Round.Drivers.nameOf(seats, carNumber, driverNumber)))

    /// A car is what `cars` says it was; where the file first mentioned it is
    /// the laps', and is the order the grid keeps where no lap 1 reorders it.
    ///
    /// `elapsed_ms` is a column the table has of every lap, and is read through
    /// `Sql.orNull` because the `LEFT JOIN` is the one place a car can have no lap 1.
    def carBuilds(entry: Entry, drivers: List[(String, String)]): List[CarBuild] \ DbRead =
        let car = Cars.columns();
        let entered = Entries.columns();
        let laps = Laps.columns();
        Sql.statement(
            "WITH f AS (SELECT car_number, MIN(source_row) AS first_seen"
                + " FROM ${Laps.table()} WHERE ?? GROUP BY car_number),"
                + " l1 AS (SELECT * FROM ("
                + " SELECT car_number, s1_ms, elapsed_ms,"
                + " ROW_NUMBER() OVER (PARTITION BY car_number ORDER BY source_row) AS rn"
                + " FROM ${Laps.table()} WHERE ??) WHERE rn = 1)"
                + " SELECT %% FROM ${Cars.table()} c JOIN ${Entries.table()} e ON e.entry_id = c.entry_id"
                + " JOIN f ON f.car_number = c.car_number"
                + " LEFT JOIN l1 ON l1.car_number = c.car_number"
                + " WHERE ?? ORDER BY f.first_seen",
            Laps.scope(entry, Nil)
                :: Laps.scope(entry, Sql.eq(Schema.expr(laps#lapNumber), Sql.i32(1)) :: Nil)
                :: Sql.term(Rounds.scope(Schema.qualified("c", car#roundId), entry)) :: Nil,
            (
                Schema.qualified("c", car#carNumber),
                Schema.qualified("e", entered#carClass),
                Schema.qualified("e", entered#carGroup),
                Schema.qualified("e", entered#team),
                Schema.qualified("e", entered#manufacturer),
                Schema.qualified("l1", laps#s1Ms),
                Sql.orNull(Schema.qualified("l1", laps#elapsedMs))
            ))
            |> Sql.reading(row -> carBuild(drivers, row))
            |> Sql.selectAll

    def carBuild(
        drivers: List[(String, String)],
        row: (String, String, Option[String], String, String, Option[Int32], Option[Int32])
    ): CarBuild =
        match row {
            case (carNumber, class, group, team, manufacturer, lap1S1, lap1Elapsed) =>
                let car: Car = {
                    carNumber    = carNumber,
                    drivers      = driversOf(carNumber, drivers),
                    class        = class,
                    group        = group |> Option.getWithDefault(""),
                    team         = team,
                    manufacturer = manufacturer
                };
                {
                    car         = car,
                    lap1S1      = Option.map(Util.Duration.fromMillis, lap1S1),
                    lap1Elapsed = Option.map(Util.Duration.fromMillis, lap1Elapsed)
                }
        }

    def driversOf(carNumber: String, drivers: List[(String, String)]): List[String] =
        drivers
            |> List.filter(pair -> match pair { case (car, _) => car == carNumber })
            |> List.map(pair -> match pair { case (_, name) => name })

    // ---------------------------------------------------------------- track

    def track(entry: Entry): Track.Track \ DbRead =
        let sectors = fastestSectors(entry);
        let mini = fastestMiniSectors(entry);
        match sectors {
            case (s1, s2, s3, measuresMiniSectors) =>
                let sectorTime = sector -> match sector {
                    case Sector.S1 => s1
                    case Sector.S2 => s2
                    case Sector.S3 => s3
                };
                let miniSectorTime =
                    if (measuresMiniSectors)
                        Some(id -> Map.get(MiniSector.positionOf(id), mini))
                    else
                        None;
                Track.fromFastest(Events.circuit(entry#id), sectorTime, miniSectorTime)
        }

    def fastestSectors(entry: Entry): (Option[Duration], Option[Duration], Option[Duration], Bool) \ DbRead =
        let c = Laps.columns();
        Laps.rows(entry)
            |> Sql.map(_ -> (
                Sql.min(c#s1Ms),
                Sql.min(c#s2Ms),
                Sql.min(c#s3Ms),
                Sql.bool("COALESCE(MAX(mini_sector_time_ms IS NOT NULL), 0)")
            ))
            |> Sql.reading(match (s1, s2, s3, mini) -> (
                Option.map(Util.Duration.fromMillis, s1),
                Option.map(Util.Duration.fromMillis, s2),
                Option.map(Util.Duration.fromMillis, s3),
                mini
            ))
            |> Sql.selectOne("the round's fastest sectors")

    def recorded(c: Laps.Columns): Sql.Expr[Bool] =
        Sql.ne(Schema.expr(c#lapTimeMs), Sql.i32(0))

    def fastestMiniSectors(entry: Entry): Map[Int32, Duration] \ DbRead =
        Laps.rowsBeside(entry, Sql.raw("json_each(" + Laps.table() + ".mini_sector_time_ms) m"))
            |> Sql.filter(recorded)
            |> Sql.filter(_ -> Sql.isNotNull(Sql.column("m.value")))
            |> Sql.groupBy(Sql.raw("m.key") :: Nil)
            |> Sql.orderBy(Sql.raw("m.key") :: Nil)
            |> Sql.map(_ -> (Sql.int("m.key + 1"), Sql.min(Sql.int("m.value"))))
            |> Sql.reading(match (position, fastest) ->
                (position, Util.Duration.fromMillis(fastest)))
            |> Sql.selectAll
            |> List.toMap

}
