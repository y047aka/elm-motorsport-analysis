mod Db.Schema {

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
            + List.join(", ", placeholders()) + ")"

    /// An array column takes an explicit cast. A bound string reaches the
    /// server as `text`, which the column refuses, and the placeholder is the
    /// only place left to say what it is.
    def placeholders(): List[String] =
        definitions() |> List.map(definition ->
            if (String.endsWith({suffix = "int[]"}, definition)) "?::int[]" else "?"
        )

    pub def anyRow(season: Int32, round: String): String =
        "SELECT 1 FROM laps WHERE " + scope(season, round) + " LIMIT 1"

    pub def selectRound(season: Int32, round: String): String =
        "SELECT " + List.join(", ", columns())
            + " FROM laps WHERE " + scope(season, round)
            + " ORDER BY source_row"

    /// In the order `Db.LapRow.values` produces them.
    pub def columns(): List[String] =
        definitions() |> List.map(d -> String.takeWhile(c -> c != ' ', d))

    def definitions(): List[String] =
        "season int not null" ::
        "round text not null" ::
        "source_row int not null" ::
        "car_number text not null" ::
        "class text not null" ::
        "car_group text not null" ::
        "team text not null" ::
        "manufacturer text not null" ::
        "driver_number int not null" ::
        "driver_name text not null" ::
        "lap_number int not null" ::
        "lap_time_ms int not null" ::
        "lap_improvement int not null" ::
        "crossing_finish_line_in_pit boolean not null" ::
        "s1_ms int" ::
        "s1_improvement int not null" ::
        "s2_ms int" ::
        "s2_improvement int not null" ::
        "s3_ms int" ::
        "s3_improvement int not null" ::
        "kph text not null" ::
        "elapsed_ms int not null" ::
        "hour_ms int not null" ::
        "top_speed text not null" ::
        "pit_time_ms int" ::
        "flag_at_fl text not null" ::
        // In `Motorsport.MiniSector.all()` order, so a subscript is a place
        // on the circuit.
        "mini_sector_time_ms int[]" ::
        "mini_sector_elapsed_ms int[]" ::
        Nil

}
