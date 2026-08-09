mod Motorsport.Calendar {

    pub type alias Round = {
        id   = String,
        date = String
    }

    /// The rounds are in the order the season ran them.
    pub type alias Season = {
        season = Int32,
        rounds = List[Round]
    }

    /// A round with its season carried alongside, which is what it takes to name
    /// one: `spa_6h` ran in 2025 and in 2026, and nothing inside either file
    /// says which year it is.
    pub type alias Entry = {
        season = Int32,
        id     = String,
        date   = String
    }

    /// The seasons the app has, newest first.
    ///
    /// Written down rather than derived, because none of it is in the feed: the
    /// `HOUR` column is a time of day with no date behind it, and no column
    /// carries the year. A calendar is knowledge about the championship.
    ///
    /// Newest first is the whole of what makes a season the latest. An order
    /// plus a flag saying which season was current could disagree with itself;
    /// this cannot.
    ///
    /// A season is listed once it has data, so 2024 opens at Le Mans: a card
    /// linking to a file nobody has is worse than no card.
    pub def seasons(): List[Season] =
        {
            season = 2026,
            rounds =
                { id = "imola_6h",     date = "2026-04-19" } ::
                { id = "spa_6h",       date = "2026-05-09" } ::
                { id = "le_mans_24h",  date = "2026-06-13" } ::
                { id = "sao_paulo_6h", date = "2026-07-12" } ::
                Nil
        } ::
        {
            season = 2025,
            rounds =
                { id = "qatar_1812km", date = "2025-03-01" } ::
                { id = "imola_6h",     date = "2025-04-20" } ::
                { id = "spa_6h",       date = "2025-05-10" } ::
                { id = "le_mans_24h",  date = "2025-06-14" } ::
                { id = "sao_paulo_6h", date = "2025-07-13" } ::
                { id = "cota_6h",      date = "2025-09-07" } ::
                { id = "fuji_6h",      date = "2025-09-28" } ::
                Nil
        } ::
        {
            season = 2024,
            rounds =
                { id = "le_mans_24h",  date = "2024-06-15" } ::
                { id = "fuji_6h",      date = "2024-09-15" } ::
                { id = "bahrain_8h",   date = "2024-11-02" } ::
                Nil
        } ::
        Nil

    /// `None`, not an empty list: a year nobody has filed is not a year that ran
    /// no races.
    pub def rounds(season: Int32): Option[List[Round]] =
        seasons()
            |> List.find(s -> s#season == season)
            |> Option.map(s -> s#rounds)

    /// Every round there is. This is the CLI's whole worklist.
    pub def entries(): List[Entry] =
        seasons() |> List.flatMap(s ->
            s#rounds |> List.map(r -> { season = s#season, id = r#id, date = r#date })
        )

    pub def find(season: Int32, eventId: String): Option[Entry] =
        entries() |> List.find(e -> e#season == season and e#id == eventId)

}
