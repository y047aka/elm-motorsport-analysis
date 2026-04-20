mod Csv {

    pub type alias LapRecord = {
        carNumber = String,
        driverName = String,
        lapNumber = String,
        lapTime = String,
        kph = String,
        class = String,
        team = String
    }

    pub def parseLine(line: String): Option[LapRecord] =
        let fields = String.split({regex = ";"}, line);
        let len = List.length(fields);
        if (len >= 25)
            forM(
                carNumber   <- List.nth(0, fields);
                driverName  <- List.nth(19, fields);
                lapNumber   <- List.nth(2, fields);
                lapTime     <- List.nth(3, fields);
                kph         <- List.nth(12, fields);
                class       <- List.nth(21, fields);
                team        <- List.nth(23, fields)
            ) yield {
                carNumber   = carNumber,
                driverName  = driverName,
                lapNumber   = lapNumber,
                lapTime     = lapTime,
                kph         = kph,
                class       = class,
                team        = team
            }
        else
            None

    pub def parseLines(lines: List[String]): List[LapRecord] =
        lines |> List.filterMap(parseLine)

    pub def formatTable(records: List[LapRecord]): String =
        let header = formatRow("Car", "Driver", "Lap", "Time", "KPH", "Class", "Team");
        let separator = String.repeat(100, "-");
        let rows = records |> List.map(r ->
            formatRow(r#carNumber, r#driverName, r#lapNumber, r#lapTime, r#kph, r#class, r#team)
        );
        List.join("\n", header :: separator :: rows)

    def formatRow(car: String, driver: String, lap: String, time: String, kph: String, cls: String, team: String): String =
        let pad = s -> String.padRight(5, ' ', s);
        "${pad(car)} ${String.padRight(20, ' ', driver)} ${pad(lap)} ${String.padRight(12, ' ', time)} ${pad(kph)} ${String.padRight(12, ' ', cls)} ${team}"

}
