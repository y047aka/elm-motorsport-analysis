mod Db.Schema {

    use Db.Laps.Columns

    /// The rows of one round: every reading of the table is of a single round,
    /// and the pair is what names one.
    pub def scope(season: Int32, round: String): String =
        "season = ${season} AND round = '${quote(round)}'"

    /// `(hour - elapsed) mod 24h`, which the feed holds constant across a file
    /// and which is therefore where the round's start time is written.
    pub def hourOffset(): String =
        "((hour_ms - elapsed_ms) % 86400000 + 86400000) % 86400000"

    def quote(value: String): String =
        String.replace({src = "'"}, {dst = "''"}, value)

    pub def dropTable(): String =
        "DROP TABLE IF EXISTS laps"

    pub def createTable(): String =
        "CREATE TABLE laps (\n"
            + (definitions() |> List.map(d -> "  ${d}") |> List.join(",\n"))
            + ",\n  PRIMARY KEY (season, round, car_number, lap_number)"
            + ",\n  UNIQUE (season, round, source_row)\n)"

    pub def insert(): String =
        "INSERT INTO laps (" + List.join(", ", columns()) + ") VALUES ("
            + List.join(", ", List.map(_ -> "?", columns())) + ")"

    pub def anyRow(season: Int32, round: String): String =
        "SELECT 1 FROM laps WHERE " + scope(season, round) + " LIMIT 1"

    pub def columns(): List[String] =
        Columns.all() |> List.map(c -> c#name)

    def definitions(): List[String] =
        Columns.all() |> List.map(c -> "${c#name} ${c#sqlType}")

}
