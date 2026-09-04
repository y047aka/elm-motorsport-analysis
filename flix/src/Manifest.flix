/// The file the app reads before it has asked for a round -- rendered the
/// same way whether the rounds are exported or served, since only the root a
/// path is built under differs between them.
mod Manifest {

    use Util.Json.Encode
    use Util.Json.Encode.JsonValue.{JsonObject, JsonString, JsonInt, JsonArray}
    use Motorsport.Calendar.Round
    use Motorsport.Calendar.Season
    use Motorsport.Events

    /// The paths are stated rather than left to a rule the reader reproduces. A
    /// convention both sides know is two copies of it, and the app has no way to
    /// notice when its copy stops matching where the files went.
    pub def toJson(urlRoot: String, seasons: List[Season]): Encode.JsonValue =
        JsonObject(
            ("seasons", JsonArray(seasons |> List.map(seasonToJson(urlRoot)))) ::
            Nil
        )

    def seasonToJson(urlRoot: String): Season -> Encode.JsonValue =
        s -> JsonObject(
            ("season", JsonInt(s#season)) ::
            ("rounds", JsonArray(s#rounds |> List.map(roundToJson(urlRoot, s#season)))) ::
            Nil
        )

    def roundToJson(urlRoot: String, season: Int32): Round -> Encode.JsonValue =
        r -> {
            let stem = "${urlRoot}/${season}/${r#id}";
            JsonObject(
                ("id",      JsonString(r#id)) ::
                ("name",    JsonString(Events.displayName(r#id))) ::
                ("date",    JsonString(r#date)) ::
                ("summary", JsonString("${stem}.json")) ::
                ("laps",    JsonString("${stem}_laps.jsonl")) ::
                Nil
            )
        }

}
