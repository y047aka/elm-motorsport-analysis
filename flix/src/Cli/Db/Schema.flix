mod Cli.Db.Schema {

    pub def dropTable(): String =
        "DROP TABLE IF EXISTS laps"

    pub def createTable(): String =
        "CREATE TABLE laps (\n"
            + (definitions() |> List.map(d -> "  ${d}") |> List.join(",\n"))
            + ",\n  PRIMARY KEY (season, round, car_number, lap_number)\n)"

    pub def insert(): String =
        "INSERT INTO laps (" + List.join(", ", columns()) + ") VALUES ("
            + List.join(", ", placeholders()) + ")"

    /// `jsonb` takes an explicit cast. A bound string reaches the server as
    /// `text`, which the column refuses, and the placeholder is the only place
    /// left to say what it is.
    def placeholders(): List[String] =
        definitions() |> List.map(definition ->
            if (String.endsWith({suffix = "jsonb"}, definition)) "?::jsonb" else "?"
        )

    /// In the order `Cli.Db.LapRow.values` produces them.
    pub def columns(): List[String] =
        definitions() |> List.map(d -> String.takeWhile(c -> c != ' ', d))

    def definitions(): List[String] =
        "season int not null" ::
        "round text not null" ::
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
        "mini_sectors jsonb" ::
        Nil

}
