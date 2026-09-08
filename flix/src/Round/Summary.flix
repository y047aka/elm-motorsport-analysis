/// The round's summary, read back out of the rows it was just loaded into.
/// What is decided here is only what the feed does not say outright -- the
/// grid order, the time limit, the shape of the circuit -- and each of those
/// decisions stays in `Motorsport`: this reads, and hands over.
mod Round.Summary {

    use Db.CarRow.CarRow
    use Db.Cars
    use Db.Entries
    use Db.Entries.EntryRow
    use Db.LapRow.LapRow
    use Db.Laps
    use Db.Rounds
    use Db.Schema
    use Db.Schema.Column
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

    /// The round's rows as a fragment, for the queries reading them from
    /// inside one of their own.
    def where_(entry: Entry, predicates: List[Sql.Expr[Bool]]): Sql.Frag =
        Sql.term(Sql.every(Laps.inRound(entry) :: predicates))

    // ---------------------------------------------------------- particulars

    def particulars(entry: Entry): Metadata.Particulars \ DbRead =
        Laps.rows(entry)
            |> Sql.map(_ -> (
                startedAt(entry),
                Sql.optionalInt("MAX(elapsed_ms)"),
                Sql.optionalInt("MAX(lap_number)")
            ))
            |> Sql.reading(match (started, duration, lapTotal) -> Metadata.particulars(
                Option.map(ms -> Hour.Hour(ms), started),
                Util.Duration.fromMillis(Option.getWithDefault(0, duration)),
                Option.getWithDefault(0, lapTotal)
            ))
            |> Sql.selectOne("the round's particulars")

    /// The round's start time, which is the offset the file's first lap
    /// carries.
    def startedAt(entry: Entry): Sel[Option[Int32]] =
        Sql.optionalIntOf(Sql.frags(
            Sql.raw("(SELECT ${Schema.nameOf(Laps.hourOffsetMs())}"
                + " FROM " + Laps.table() + " WHERE") ::
            where_(entry, Nil) ::
            Sql.raw("ORDER BY source_row LIMIT 1)") :: Nil
        ))

    // ----------------------------------------------------------------- cars

    def cars(entry: Entry, seats: Round.Drivers.Seats): List[CarBuild] \ DbRead =
        carBuilds(entry, driverNames(entry, seats))

    /// `(car number, driver name)` in the order the file first showed each
    /// seat, which is the order a car's drivers are listed in. The order is
    /// the laps' and the name is `car_drivers`', so the reading is of the one
    /// and the naming of the other.
    def driverNames(entry: Entry, seats: Round.Drivers.Seats): List[(String, String)] \ DbRead =
        let c = Laps.columns();
        Sql.access(
                Sql.frags(
                    Sql.raw("(SELECT car_number, driver_number, MIN(source_row) AS first_seen"
                        + " FROM " + Laps.table() + " WHERE") ::
                    where_(entry, Nil) ::
                    Sql.raw("GROUP BY car_number, driver_number) d") :: Nil
                ),
                { carNumber = c#carNumber, driverNumber = c#driverNumber }
            )
            |> Sql.orderBy(Sql.raw("first_seen") :: Nil)
            |> Sql.map(d -> (d#carNumber, d#driverNumber))
            |> Sql.selectAll
            |> List.map(match (carNumber, driverNumber) ->
                (carNumber, Round.Drivers.nameOf(seats, carNumber, driverNumber)))

    /// A car is what `cars` says it was; where the file first mentioned it is
    /// the laps', and is the order the grid keeps where no lap 1 reorders it.
    def carBuilds(entry: Entry, drivers: List[(String, String)]): List[CarBuild] \ DbRead =
        let car = carColumns();
        let entered = entryColumns();
        let lap1 = lap1Columns();
        Sql.access(
                Sql.frags(
                    Sql.raw(Cars.table() + " c JOIN " + Entries.table() + " e ON") ::
                    Sql.term(Sql.eq(Schema.expr(entered#entryId), Schema.expr(car#entryId))) ::
                    Sql.raw("JOIN f ON") ::
                    Sql.term(Sql.eq(Sql.column("f.car_number"), Schema.expr(car#carNumber))) ::
                    Sql.raw("LEFT JOIN l1 ON") ::
                    Sql.term(Sql.eq(Schema.expr(lap1#carNumber), Schema.expr(car#carNumber))) :: Nil
                ),
                { car = car, entry = entered, lap1 = lap1 }
            )
            |> Sql.filter(t -> Rounds.scope(t#car#roundId, entry))
            |> Sql.using(Sql.frags(
                Sql.raw("f AS (SELECT car_number, MIN(source_row) AS first_seen"
                    + " FROM " + Laps.table() + " WHERE") ::
                where_(entry, Nil) ::
                Sql.raw("GROUP BY car_number)") :: Nil
            ))
            |> Sql.using(Sql.frags(
                Sql.raw("l1 AS (SELECT * FROM ("
                    + " SELECT car_number, s1_ms, elapsed_ms, " + firstPerCar()
                    + " FROM " + Laps.table() + " WHERE") ::
                where_(entry, Sql.eq(Schema.expr(Laps.columns()#lapNumber), Sql.i32(1)) :: Nil) ::
                Sql.raw(") WHERE rn = 1)") :: Nil
            ))
            |> Sql.orderBy(Sql.raw("f.first_seen") :: Nil)
            |> Sql.map(t -> (
                t#car#carNumber,
                t#entry#carClass,
                t#entry#carGroup,
                t#entry#team,
                t#entry#manufacturer,
                t#lap1#s1Ms,
                Sql.orNull(t#lap1#elapsedMs)
            ))
            |> Sql.reading(row -> carBuild(drivers, row))
            |> Sql.selectAll

    /// The round's cars under the name the join gives that side.
    def carColumns(): {
        roundId = Column[CarRow, Int32],
        carNumber = Column[CarRow, String],
        entryId = Column[CarRow, Int32]
    } =
        let c = Cars.columns();
        {
            roundId   = Schema.qualified("c", c#roundId),
            carNumber = Schema.qualified("c", c#carNumber),
            entryId   = Schema.qualified("c", c#entryId)
        }

    /// The season's entries under the name the join gives that side, which is
    /// where a car's description is.
    def entryColumns(): {
        entryId = Column[EntryRow, Int32],
        carClass = Column[EntryRow, String],
        carGroup = Column[EntryRow, Option[String]],
        team = Column[EntryRow, String],
        manufacturer = Column[EntryRow, String]
    } =
        let e = Entries.columns();
        {
            entryId      = Schema.qualified("e", e#entryId),
            carClass     = Schema.qualified("e", e#carClass),
            carGroup     = Schema.qualified("e", e#carGroup),
            team         = Schema.qualified("e", e#team),
            manufacturer = Schema.qualified("e", e#manufacturer)
        }

    /// Each is a column of `laps`, so what it reads back as is the type the
    /// table gives it -- and `elapsed_ms`, which the table has of every lap, is
    /// read through `Sql.orNull` because the join is the one place a car can
    /// have no lap 1.
    def lap1Columns(): { carNumber = Column[LapRow, String], s1Ms = Column[LapRow, Option[Int32]], elapsedMs = Column[LapRow, Int32] } =
        let c = Laps.columns();
        {
            carNumber = Schema.qualified("l1", c#carNumber),
            s1Ms      = Schema.qualified("l1", c#s1Ms),
            elapsedMs = Schema.qualified("l1", c#elapsedMs)
        }

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

    def firstPerCar(): String =
        "ROW_NUMBER() OVER (PARTITION BY car_number ORDER BY source_row) AS rn"

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
                Track.fromFastest(Events.direction(entry#id), sectorTime, miniSectorTime)
        }

    def fastestSectors(entry: Entry): (Option[Duration], Option[Duration], Option[Duration], Bool) \ DbRead =
        Laps.rows(entry)
            |> Sql.map(_ -> (
                Sql.optionalInt("MIN(s1_ms)"),
                Sql.optionalInt("MIN(s2_ms)"),
                Sql.optionalInt("MIN(s3_ms)"),
                Sql.bool("COALESCE(MAX(mini_sector_time_ms IS NOT NULL), 0)")
            ))
            |> Sql.reading(match (s1, s2, s3, mini) -> (
                Option.map(Util.Duration.fromMillis, s1),
                Option.map(Util.Duration.fromMillis, s2),
                Option.map(Util.Duration.fromMillis, s3),
                mini
            ))
            |> Sql.selectOne("the round's fastest sectors")

    /// The feed writes a lap it did not record as `0.000`, and the mini-sectors
    /// of such a lap are not a lap of the circuit either.
    def recorded(c: Laps.Columns): Sql.Expr[Bool] =
        Sql.ne(Schema.expr(c#lapTimeMs), Sql.i32(0))

    def fastestMiniSectors(entry: Entry): Map[Int32, Duration] \ DbRead =
        Laps.rowsBeside(entry, Sql.raw("json_each(" + Laps.table() + ".mini_sector_time_ms) m"))
            |> Sql.filter(recorded)
            |> Sql.filter(_ -> Sql.isNotNull(Sql.column("m.value")))
            |> Sql.groupBy(Sql.raw("m.key") :: Nil)
            |> Sql.orderBy(Sql.raw("m.key") :: Nil)
            |> Sql.map(_ -> (Sql.int("m.key + 1"), Sql.int("MIN(m.value)")))
            |> Sql.reading(match (position, fastest) ->
                (position, Util.Duration.fromMillis(fastest)))
            |> Sql.selectAll
            |> List.toMap

}
