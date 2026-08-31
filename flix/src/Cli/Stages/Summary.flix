/// The round's summary, read back out of the rows it was just loaded into.
/// What is decided here is only what the feed does not say outright -- the
/// grid order, the time limit, the shape of the circuit -- and each of those
/// decisions stays in `Motorsport`: this reads, and hands over.
mod Cli.Stages.Summary {

    use Cli.Db
    use Cli.Db.Row
    use Cli.Db.Schema
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

    pub def read(entry: Entry): Result[String, Metadata.Metadata] \ Db =
        forM(
            race   <- particulars(entry);
            shape  <- track(entry);
            builds <- cars(entry)
        ) yield Metadata.fromReadings(entry, race, shape, builds)

    def scope(entry: Entry): String =
        Schema.scope(entry#season, entry#id)

    // ---------------------------------------------------------- particulars

    def particulars(entry: Entry): Result[String, Metadata.Particulars] \ Db =
        Db.fetch(
            "SELECT MAX(elapsed_ms), MAX(lap_number),"
                + " (SELECT " + Schema.hourOffset() + " FROM laps WHERE " + scope(entry)
                + " ORDER BY source_row LIMIT 1)"
                + " FROM laps WHERE " + scope(entry)
        ) |> Result.flatMap(rows -> match rows {
            case row :: _ =>
                forM(
                    duration  <- Row.optionalInt(0, row);
                    lapTotal  <- Row.optionalInt(1, row);
                    startedAt <- Row.optionalInt(2, row)
                ) yield Metadata.particulars(
                    Option.map(ms -> Hour.Hour(ms), startedAt),
                    Util.Duration.fromMillis(Option.getWithDefault(0, duration)),
                    Option.getWithDefault(0, lapTotal)
                )
            case Nil => Err("the round's particulars came back with no row")
        })

    // ----------------------------------------------------------------- cars

    def cars(entry: Entry): Result[String, List[CarBuild]] \ Db =
        forM(
            drivers <- driverNames(entry);
            builds  <- carBuilds(entry, drivers)
        ) yield builds

    /// `(car number, driver name)` in the order the file first showed each
    /// pair, which is the order a car's drivers are listed in.
    def driverNames(entry: Entry): Result[String, List[(String, String)]] \ Db =
        Db.fetch(
            "SELECT car_number, driver_name FROM ("
                + " SELECT car_number, driver_name, MIN(source_row) AS first_seen"
                + " FROM laps WHERE " + scope(entry)
                + " GROUP BY car_number, driver_name) d ORDER BY first_seen"
        ) |> Result.flatMap(Result.traverse(row ->
            forM(
                carNumber  <- Row.text(0, row);
                driverName <- Row.text(1, row)
            ) yield (carNumber, driverName)
        ))

    /// A car is what the file first said it was. Grouping by the attributes
    /// instead would be a row per distinct combination, so a feed that changed
    /// a car's team mid-round would put that car on the grid twice.
    def carBuilds(entry: Entry, drivers: List[(String, String)]): Result[String, List[CarBuild]] \ Db =
        Db.fetch(
            "WITH c AS ("
                + " SELECT DISTINCT ON (car_number)"
                + " car_number, class, car_group, team, manufacturer, source_row AS first_seen"
                + " FROM laps WHERE " + scope(entry)
                + " ORDER BY car_number, source_row),"
                + " l1 AS ("
                + " SELECT DISTINCT ON (car_number) car_number, s1_ms, elapsed_ms"
                + " FROM laps WHERE " + scope(entry) + " AND lap_number = 1"
                + " ORDER BY car_number, source_row)"
                + " SELECT c.car_number, c.class, c.car_group, c.team, c.manufacturer,"
                + " l1.s1_ms, l1.elapsed_ms"
                + " FROM c LEFT JOIN l1 ON l1.car_number = c.car_number"
                + " ORDER BY c.first_seen"
        ) |> Result.flatMap(Result.traverse(row ->
            forM(
                carNumber    <- Row.text(0, row);
                class        <- Row.text(1, row);
                group        <- Row.text(2, row);
                team         <- Row.text(3, row);
                manufacturer <- Row.text(4, row);
                lap1S1       <- Row.optionalInt(5, row);
                lap1Elapsed  <- Row.optionalInt(6, row)
            ) yield {
                let car: Car = {
                    carNumber    = carNumber,
                    drivers      = driversOf(carNumber, drivers),
                    class        = class,
                    group        = group,
                    team         = team,
                    manufacturer = manufacturer
                };
                {
                    car         = car,
                    lap1S1      = Option.map(Util.Duration.fromMillis, lap1S1),
                    lap1Elapsed = Option.map(Util.Duration.fromMillis, lap1Elapsed)
                }
            }
        ))

    def driversOf(carNumber: String, drivers: List[(String, String)]): List[String] =
        drivers
            |> List.filter(pair -> match pair { case (car, _) => car == carNumber })
            |> List.map(pair -> match pair { case (_, name) => name })

    // ---------------------------------------------------------------- track

    def track(entry: Entry): Result[String, Track.Track] \ Db =
        forM(
            sectors <- fastestSectors(entry);
            mini    <- fastestMiniSectors(entry)
        ) yield match sectors {
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
                Track.fromFastest(Events.direction(entry#id), sectorTime, miniSectorTime)
        }

    def fastestSectors(entry: Entry): Result[String, (Option[Duration], Option[Duration], Option[Duration], Bool)] \ Db =
        Db.fetch(
            "SELECT MIN(s1_ms), MIN(s2_ms), MIN(s3_ms),"
                + " COALESCE(BOOL_OR(mini_sector_time_ms IS NOT NULL), false)::int"
                + " FROM laps WHERE " + scope(entry)
        ) |> Result.flatMap(rows -> match rows {
            case row :: _ =>
                forM(
                    s1   <- Row.optionalInt(0, row);
                    s2   <- Row.optionalInt(1, row);
                    s3   <- Row.optionalInt(2, row);
                    mini <- Row.int(3, row)
                ) yield (
                    Option.map(Util.Duration.fromMillis, s1),
                    Option.map(Util.Duration.fromMillis, s2),
                    Option.map(Util.Duration.fromMillis, s3),
                    mini == 1
                )
            case Nil => Err("the round's fastest sectors came back with no row")
        })

    /// The feed writes a lap it did not record as `0.000`, and the mini-sectors
    /// of such a lap are not a lap of the circuit either.
    def fastestMiniSectors(entry: Entry): Result[String, Map[Int32, Duration]] \ Db =
        Db.fetch(
            "SELECT ord::int, MIN(v) FROM laps,"
                + " UNNEST(mini_sector_time_ms) WITH ORDINALITY u(v, ord)"
                + " WHERE " + scope(entry) + " AND lap_time_ms <> 0 AND v IS NOT NULL"
                + " GROUP BY ord ORDER BY ord"
        ) |> Result.flatMap(Result.traverse(row ->
            forM(
                position <- Row.int(0, row);
                fastest  <- Row.int(1, row)
            ) yield (position, Util.Duration.fromMillis(fastest))
        )) |> Result.map(List.toMap)

}
