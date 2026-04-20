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
