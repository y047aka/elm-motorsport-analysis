mod Lap {

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
        Json.JsonValue.JsonObject(
            ("carNumber",  Json.JsonValue.JsonString(record#carNumber)) ::
            ("driverName", Json.JsonValue.JsonString(record#driverName)) ::
            ("lapNumber",  Json.JsonValue.JsonString(record#lapNumber)) ::
            ("lapTime",    Json.JsonValue.JsonString(record#lapTime)) ::
            ("kph",        Json.JsonValue.JsonString(record#kph)) ::
            ("class",      Json.JsonValue.JsonString(record#class)) ::
            ("team",       Json.JsonValue.JsonString(record#team)) ::
            Nil
        )

    pub def toJsonArray(records: List[LapRecord]): Json.JsonValue =
        Json.JsonValue.JsonArray(List.map(toJson, records))

}
