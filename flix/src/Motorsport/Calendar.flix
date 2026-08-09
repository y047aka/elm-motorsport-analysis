mod Motorsport.Calendar {

    /// One round of a season: the id its files are filed under, and the day it
    /// was run.
    pub type alias Round = {
        id   = String,
        date = String
    }

    /// The rounds a season ran, in the order it ran them.
    ///
    /// None of this is in the timing feed. The feed's `HOUR` column is a time of
    /// day with no date behind it, and no column carries the year -- which is why
    /// `Cli.FileTask.season` has to read the season off the directory the CSV came
    /// in on. A calendar is knowledge about the championship, so it is written
    /// down here rather than derived.
    ///
    /// A season with no entry resolves to `None` rather than to an empty list:
    /// a year nobody has filed is not a year that ran no races.
    pub def rounds(season: Int32): Option[List[Round]] =
        match season {
            case 2024 => Some(
                { id = "le_mans_24h",  date = "2024-06-15" } ::
                { id = "fuji_6h",      date = "2024-09-15" } ::
                { id = "bahrain_8h",   date = "2024-11-02" } ::
                Nil
            )
            case 2025 => Some(
                { id = "qatar_1812km", date = "2025-03-01" } ::
                { id = "imola_6h",     date = "2025-04-20" } ::
                { id = "spa_6h",       date = "2025-05-10" } ::
                { id = "le_mans_24h",  date = "2025-06-14" } ::
                { id = "sao_paulo_6h", date = "2025-07-13" } ::
                { id = "cota_6h",      date = "2025-09-07" } ::
                { id = "fuji_6h",      date = "2025-09-28" } ::
                Nil
            )
            case 2026 => Some(
                { id = "imola_6h",     date = "2026-04-19" } ::
                { id = "spa_6h",       date = "2026-05-09" } ::
                { id = "le_mans_24h",  date = "2026-06-13" } ::
                { id = "sao_paulo_6h", date = "2026-07-12" } ::
                Nil
            )
            case _ => None
        }

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

}
