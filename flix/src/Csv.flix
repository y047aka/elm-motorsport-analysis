mod Csv {

    pub def parseLine(line: String): Option[Lap.LapRecord] =
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

    pub def parseLines(lines: List[String]): List[Lap.LapRecord] =
        lines |> List.filterMap(parseLine)

}
