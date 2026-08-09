mod Motorsport.Calendar {

    /// One round of a season: the id its files are filed under, and the day it
    /// was run.
    pub type alias Round = {
        id   = String,
        date = String
    }

    /// A season and the rounds it ran, in the order it ran them.
    pub type alias Season = {
        season = Int32,
        rounds = List[Round]
    }

    /// One round with its season carried alongside, which is what it takes to
    /// name a round: `spa_6h` ran in 2025 and in 2026, and nothing inside either
    /// file says which year it is.
    ///
    /// This is what the CLI works from. It walks the calendar and builds the
    /// paths, rather than walking the paths and asking the calendar about what
    /// it found -- which is why nothing here has to be parsed back out of a
    /// directory name.
    pub type alias Entry = {
        season = Int32,
        id     = String,
        date   = String
    }

    /// The seasons the app has, newest first.
    ///
    /// None of this is in the timing feed. The feed's `HOUR` column is a time of
    /// day with no date behind it, and no column carries the year -- which is why
    /// `Cli.FileTask.season` has to read the season off the directory the CSV came
    /// in on. A calendar is knowledge about the championship, so it is written
    /// down here rather than derived.
    ///
    /// The order is the order the index page lists them in, newest at the top,
    /// and it is the whole of what makes one season the latest. A file that
    /// carried the seasons in some other order and a flag saying which was
    /// current could disagree with itself; this cannot.
    ///
    /// A season is listed once it has data, so 2024 opens at Le Mans -- the
    /// rounds it ran before that are not here, because a card linking to a file
    /// nobody has is worse than no card.
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

    /// The rounds one season ran.
    ///
    /// A season with no entry resolves to `None` rather than to an empty list:
    /// a year nobody has filed is not a year that ran no races.
    pub def rounds(season: Int32): Option[List[Round]] =
        seasons()
            |> List.find(s -> s#season == season)
            |> Option.map(s -> s#rounds)

    /// Every round there is, seasons flattened away, in the order they are
    /// listed. This is the CLI's whole worklist.
    pub def entries(): List[Entry] =
        seasons() |> List.flatMap(s ->
            s#rounds |> List.map(r -> { season = s#season, id = r#id, date = r#date })
        )

    /// The one round with this season and id, if the calendar holds it.
    ///
    /// Keyed by season as well as by id, unlike `Motorsport.Events`: a round
    /// keeps its name and its direction from year to year, and only its date
    /// moves.
    pub def find(season: Int32, eventId: String): Option[Entry] =
        entries() |> List.find(e -> e#season == season and e#id == eventId)

}
