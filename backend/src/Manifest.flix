/// The file the app reads before it has asked for a round -- rendered the
/// same way whether the rounds are exported or served, since only the root a
/// path is built under differs between them.
pub mod Manifest {

    use oj::OrderedJson
    use oj::OrderedJson.Json.{JObject, JString, JNumber, JArray}
    use Motorsport.Calendar.Round
    use Motorsport.Calendar.Season
    use Motorsport.Events

    /// The paths are stated rather than left to a rule the reader reproduces. A
    /// convention both sides know is two copies of it, and the app has no way to
    /// notice when its copy stops matching where the files went.
    pub def toJson(urlRoot: String, seasons: List[Season]): OrderedJson.Json =
        JObject(
            ("seasons", JArray(seasons |> List.map(seasonToJson(urlRoot)) |> List.toVector)) ::
            Nil
        )

    def seasonToJson(urlRoot: String): Season -> OrderedJson.Json =
        s -> JObject(
            ("season", JNumber(Int32.toBigDecimal(s#season))) ::
            ("rounds", JArray(s#rounds |> List.map(roundToJson(urlRoot, s#season)) |> List.toVector)) ::
            Nil
        )

    def roundToJson(urlRoot: String, season: Int32): Round -> OrderedJson.Json =
        r -> {
            let stem = "${urlRoot}/${season}/${r#id}";
            JObject(
                ("id",       JString(r#id)) ::
                ("name",     JString(Events.displayName(r#id))) ::
                ("date",     JString(r#date)) ::
                ("summary",  JString("${stem}.json")) ::
                ("laps",     JString("${stem}_laps.jsonl")) ::
                ("timeline", JString("${stem}_timeline.jsonl")) ::
                Nil
            )
        }

}
