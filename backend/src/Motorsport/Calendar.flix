/// Which rounds there are, the days they ran, what they are called, and the
/// ground they ran on -- read from a file, not written down here.
/// A round joins the calendar file before it joins anywhere -- `/skill:add-round` says the trip from a CSV to a served round.
pub mod Motorsport.Calendar {

    use Motorsport.Circuit.Circuit

    pub type alias Round = {
        id      = String,
        date    = String,
        name    = String,
        circuit = Option[Circuit]
    }

    /// The rounds are in the order the season ran them.
    pub type alias Season = {
        season = Int32,
        rounds = List[Round]
    }

    /// The championship and its seasons, newest first.
    ///
    /// None of it is in the feed: the `HOUR` column is a time of day with no
    /// date behind it, and no column carries the year. A calendar is knowledge
    /// about the championship, which is why it is a file the run reads rather
    /// than a thing the rows are queried for.
    ///
    /// Newest first is the whole of what makes a season the latest. An order
    /// plus a flag saying which season was current could disagree with itself;
    /// this cannot.
    ///
    /// A season is listed once it has data, so 2024 opens at Le Mans: a card
    /// linking to a file nobody has is worse than no card.
    pub type alias Calendar = {
        series  = String,
        seasons = List[Season]
    }

    /// A round with its season carried alongside, which is what it takes to name
    /// one: `spa_6h` ran in 2025 and in 2026, and nothing inside either file
    /// says which year it is.
    pub type alias Entry = {
        season  = Int32,
        id      = String,
        date    = String,
        name    = String,
        circuit = Option[Circuit]
    }

    /// The one word both roots are built on.
    pub def series(calendar: Calendar): String =
        calendar#series

    /// `None`, not an empty list: a year nobody has filed is not a year that ran
    /// no races.
    pub def rounds(calendar: Calendar, season: Int32): Option[List[Round]] =
        calendar#seasons
            |> List.find(s -> s#season == season)
            |> Option.map(s -> s#rounds)

    /// Every round there is. This is the CLI's whole worklist.
    pub def entries(calendar: Calendar): List[Entry] =
        calendar#seasons |> List.flatMap(s ->
            s#rounds |> List.map(r ->
                { season = s#season, id = r#id, date = r#date, name = r#name, circuit = r#circuit }
            )
        )

    pub def find(calendar: Calendar, season: Int32, eventId: String): Option[Entry] =
        entries(calendar) |> List.find(e -> e#season == season and e#id == eventId)

}
