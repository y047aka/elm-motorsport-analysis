mod Motorsport.Calendar {

    use Util.Json.Encode
    use Util.Json.Encode.JsonValue.{JsonObject, JsonString, JsonInt, JsonArray}
    use Motorsport.Events

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

    /// The day one round was run, if the calendar holds it.
    ///
    /// Keyed by season as well as by id, unlike `Motorsport.Events`: a round
    /// keeps its name and its direction from year to year, and only its date
    /// moves.
    pub def dateOf(season: Int32, eventId: String): Option[String] =
        forM(
            rs <- rounds(season);
            r  <- List.find(round -> round#id == eventId, rs)
        ) yield r#date

    /// The calendar as the app reads it, names included.
    ///
    /// The name is resolved here rather than left to the reader, so the index
    /// page and the summary of the round it links to cannot end up calling the
    /// same race two different things.
    pub def toJson(): Encode.JsonValue =
        JsonObject(
            ("seasons", JsonArray(seasons() |> List.map(seasonToJson))) ::
            Nil
        )

    def seasonToJson(s: Season): Encode.JsonValue =
        JsonObject(
            ("season", JsonInt(s#season)) ::
            ("rounds", JsonArray(s#rounds |> List.map(roundToJson))) ::
            Nil
        )

    def roundToJson(r: Round): Encode.JsonValue =
        JsonObject(
            ("id",   JsonString(r#id)) ::
            ("name", JsonString(Events.displayName(r#id))) ::
            ("date", JsonString(r#date)) ::
            Nil
        )

}
