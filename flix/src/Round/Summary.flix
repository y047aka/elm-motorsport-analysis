/// The round's summary, read back out of the rows it was just loaded into.
/// What is decided here is only what the feed does not say outright -- the
/// grid order, the time limit, the shape of the circuit -- and each of those
/// decisions stays in `Motorsport`: this reads, and hands over.
mod Round.Summary {

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
        Sql.intoRow(startedAt -> duration -> lapTotal -> Metadata.particulars(
            Option.map(ms -> Hour.Hour(ms), startedAt),
            Util.Duration.fromMillis(Option.getWithDefault(0, duration)),
            Option.getWithDefault(0, lapTotal)
        ))
            |> Sql.pipeline(Sql.optionalInt(
                "(SELECT " + Schema.hourOffset() + " FROM laps WHERE " + scope(entry)
                    + " ORDER BY source_row LIMIT 1)"
            ))
            |> Sql.pipeline(Sql.optionalInt("MAX(elapsed_ms)"))
            |> Sql.pipeline(Sql.optionalInt("MAX(lap_number)"))
            |> Sql.selectOne("the round's particulars", "FROM laps WHERE " + scope(entry))

    // ----------------------------------------------------------------- cars

    def cars(entry: Entry): Result[String, List[CarBuild]] \ Db =
        forM(
            drivers <- driverNames(entry);
            builds  <- carBuilds(entry, drivers)
        ) yield builds

    /// `(car number, driver name)` in the order the file first showed each
    /// pair, which is the order a car's drivers are listed in.
    def driverNames(entry: Entry): Result[String, List[(String, String)]] \ Db =
        Sql.intoRow(carNumber -> driverName -> (carNumber, driverName))
            |> Sql.pipeline(Sql.text("car_number"))
            |> Sql.pipeline(Sql.text("driver_name"))
            |> Sql.selectAll(
                "FROM (SELECT car_number, driver_name, MIN(source_row) AS first_seen"
                    + " FROM laps WHERE " + scope(entry)
                    + " GROUP BY car_number, driver_name) d ORDER BY first_seen"
            )

    /// A car is what the file first said it was. Grouping by the attributes
    /// instead would be a row per distinct combination, so a feed that changed
    /// a car's team mid-round would put that car on the grid twice.
    def carBuilds(entry: Entry, drivers: List[(String, String)]): Result[String, List[CarBuild]] \ Db =
        carBuild(drivers)
            |> Sql.selectAllWith(
                "WITH c AS (SELECT * FROM ("
                    + " SELECT car_number, class, car_group, team, manufacturer,"
                    + " source_row AS first_seen, " + firstPerCar()
                    + " FROM laps WHERE " + scope(entry) + ") WHERE rn = 1),"
                    + " l1 AS (SELECT * FROM ("
                    + " SELECT car_number, s1_ms, elapsed_ms, " + firstPerCar()
                    + " FROM laps WHERE " + scope(entry) + " AND lap_number = 1"
                    + ") WHERE rn = 1)",
                "FROM c LEFT JOIN l1 ON l1.car_number = c.car_number ORDER BY c.first_seen"
            )

    def carBuild(drivers: List[(String, String)]): Sel[CarBuild] =
        Sql.intoRow(carNumber -> class -> group -> team -> manufacturer -> lap1S1 -> lap1Elapsed -> {
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
        })
            |> Sql.pipeline(Sql.text("c.car_number"))
            |> Sql.pipeline(Sql.text("c.class"))
            |> Sql.pipeline(Sql.text("c.car_group"))
            |> Sql.pipeline(Sql.text("c.team"))
            |> Sql.pipeline(Sql.text("c.manufacturer"))
            |> Sql.pipeline(Sql.optionalInt("l1.s1_ms"))
            |> Sql.pipeline(Sql.optionalInt("l1.elapsed_ms"))

    def firstPerCar(): String =
        "ROW_NUMBER() OVER (PARTITION BY car_number ORDER BY source_row) AS rn"

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
        Sql.intoRow(s1 -> s2 -> s3 -> mini -> (
            Option.map(Util.Duration.fromMillis, s1),
            Option.map(Util.Duration.fromMillis, s2),
            Option.map(Util.Duration.fromMillis, s3),
            mini
        ))
            |> Sql.pipeline(Sql.optionalInt("MIN(s1_ms)"))
            |> Sql.pipeline(Sql.optionalInt("MIN(s2_ms)"))
            |> Sql.pipeline(Sql.optionalInt("MIN(s3_ms)"))
            |> Sql.pipeline(Sql.bool("COALESCE(MAX(mini_sector_time_ms IS NOT NULL), 0)"))
            |> Sql.selectOne("the round's fastest sectors", "FROM laps WHERE " + scope(entry))

    /// The feed writes a lap it did not record as `0.000`, and the mini-sectors
    /// of such a lap are not a lap of the circuit either.
    def fastestMiniSectors(entry: Entry): Result[String, Map[Int32, Duration]] \ Db =
        Sql.intoRow(position -> fastest -> (position, Util.Duration.fromMillis(fastest)))
            |> Sql.pipeline(Sql.int("m.key + 1"))
            |> Sql.pipeline(Sql.int("MIN(m.value)"))
            |> Sql.selectAll(
                "FROM laps, json_each(laps.mini_sector_time_ms) m"
                    + " WHERE " + scope(entry) + " AND lap_time_ms <> 0 AND m.value IS NOT NULL"
                    + " GROUP BY m.key ORDER BY m.key"
            )
            |> Result.map(List.toMap)

}
