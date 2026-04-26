mod Lap {

    use Json.JsonValue.{JsonObject, JsonString, JsonArray}

    pub type alias LapRecord = {
        carNumber = String,
        driverName = String,
        lapNumber = String,
        lapTime = String,
        kph = String,
        class = String,
        team = String
    }

    pub def fromCsvRow(row: Csv.CsvRow): Option[LapRecord] =
        if (List.length(row) >= 25)
            forM(
                carNumber   <- List.nth(0, row);
                driverName  <- List.nth(19, row);
                lapNumber   <- List.nth(2, row);
                lapTime     <- List.nth(3, row);
                kph         <- List.nth(12, row);
                class       <- List.nth(21, row);
                team        <- List.nth(23, row)
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

    pub def fromCsvRows(rows: List[Csv.CsvRow]): List[LapRecord] =
        rows |> List.filterMap(fromCsvRow)

    pub def toJson(record: LapRecord): Json.JsonValue =
        JsonObject(
            ("carNumber",  JsonString(record#carNumber)) ::
            ("driverName", JsonString(record#driverName)) ::
            ("lapNumber",  JsonString(record#lapNumber)) ::
            ("lapTime",    JsonString(record#lapTime)) ::
            ("kph",        JsonString(record#kph)) ::
            ("class",      JsonString(record#class)) ::
            ("team",       JsonString(record#team)) ::
            Nil
        )

    pub def toJsonArray(records: List[LapRecord]): Json.JsonValue =
        JsonArray(List.map(toJson, records))

}
