/// The round's cars, read back out of the rows it was loaded into.
mod Round.Cars {

    use Db.Cars
    use Db.Entries
    use Db.Rounds
    use Db.Schema
    use Motorsport.Calendar.Entry
    use Motorsport.Wec.RawCar

    /// Whether a run has loaded the round's cars, asked rather than read back.
    pub def loaded(entry: Entry): Bool \ DbRead =
        let found = Cars.rows(entry)
            |> Sql.limit(1)
            |> Sql.map(_ -> Sql.int("1"))
            |> Sql.selectAll;
        not List.isEmpty(found)

    /// Keyed by car number, which is the whole of what a lap carries of its
    /// car. What the feed said of one is its season's entry, so the rounds a
    /// car ran and the description of it are read together.
    pub def read(entry: Entry): Map[String, RawCar] \ DbRead =
        let car = Cars.columns();
        let e = Entries.columns();
        Sql.access(
                Sql.frags(
                    Sql.raw("${Cars.table()} JOIN ${Entries.table()} ON") ::
                    Sql.term(Sql.eq(
                        Schema.expr(Schema.qualified(Entries.table(), e#entryId)),
                        Schema.expr(Schema.qualified(Cars.table(), car#entryId))
                    )) :: Nil
                ),
                {
                    roundId = Schema.qualified(Cars.table(), car#roundId),
                    carNumber = Schema.qualified(Entries.table(), e#carNumber),
                    carClass = Schema.qualified(Entries.table(), e#carClass),
                    carGroup = Schema.qualified(Entries.table(), e#carGroup),
                    team = Schema.qualified(Entries.table(), e#team),
                    manufacturer = Schema.qualified(Entries.table(), e#manufacturer)
                }
            )
            |> Sql.filter(c -> Rounds.scope(c#roundId, entry))
            |> Sql.map(c -> (c#carNumber, c#carClass, c#carGroup, c#team, c#manufacturer))
            |> Sql.reading(match (carNumber, class, group, team, manufacturer) -> (carNumber, {
                carNumber    = carNumber,
                class        = class,
                group        = group |> Option.getWithDefault(""),
                team         = team,
                manufacturer = manufacturer
            }))
            |> Sql.selectAll
            |> List.toMap

}
