pub mod Round.Render {

    use oj::OrderedJson.Json
    use oj::OrderedJson.Json.{JObject, JArray, JNumber, JString}
    use Util.Json.Extra
    use Motorsport.Index
    use Motorsport.Metadata
    use Motorsport.MiniSector
    use Motorsport.Timeline
    use Motorsport.Wec
    use Motorsport.Sector
    use Round.Laps.Placed
    use Round.Timeline.Detail
    use Round.Timeline.Detailed
    use Round.Timeline.Rated
    use Util.Duration.Duration

    /// The round's summary and the indices read off the same rows, written as
    /// one document.
    pub def renderSummary(metadata: Metadata.Metadata, index: Index.Index): String =
        Extra.render(withIndex(Metadata.toJson(metadata), Index.toJson(hasMiniSectors(metadata), index)))

    def hasMiniSectors(metadata: Metadata.Metadata): Bool =
        match metadata#track#miniSectors {
            case None          => false
            case Some(_ :: _)  => true
            case Some(Nil)     => false
        }

    def withIndex(metadata: Json, index: Json): Json =
        match metadata {
            case JObject(fields) =>
                JObject(List.append(fields, ("index", index) :: Nil))
            case other => other
        }

    pub def renderTimelineJsonl(events: List[Detailed]): String =
        events
            |> List.map(item ->
                "${Extra.renderOnOneLine(withDetail(Timeline.toJson(item#event), item#detail))}\n")
            |> List.join("")

    def withDetail(event: Json, detail: Option[Detail]): Json =
        match (event, detail) {
            case (JObject(fields), Some(d)) =>
                JObject(List.append(fields,
                    ("driver", JString(d#driver)) ::
                    ("performance", performanceToJson(d)) :: Nil))
            case (other, _) => other
        }

    /// The same three lists the summary's `index.bestTimeChanges` is made of, so
    /// the records and the times they rate come back shaped alike.
    def performanceToJson(d: Detail): Json =
        JObject(
            ("lap", ratedToJson(d#lap)) ::
            ("sectors", JObject(d#sectors
                |> List.map(match (sector, rated) ->
                    (Motorsport.Sector.jsonKey(sector), ratedToJson(rated))))) ::
            miniField(d)
        )

    /// Absent where the round's feed measured no mini-sectors, rather than fifteen
    /// blanks. Whether the tracker has lines for the circuit is a different fact: a
    /// circuit drawn from a survey can be timed no finer than three sectors.
    ///
    /// The list is in track order and every entry names itself, which is what lets
    /// the reader keep that order without knowing the names.
    def miniField(d: Detail): List[(String, Json)] =
        match d#miniSectors {
            case None      => Nil
            case Some(minis) =>
                ("miniSectors", JArray(minis |> List.map(match (mini, rated) ->
                    namedRatedToJson(mini, rated)) |> List.toVector)) :: Nil
        }

    def namedRatedToJson(id: MiniSector.MiniSectorId, rated: Rated): Json =
        JObject(
            ("name", JString(MiniSector.csvName(id))) ::
            ("time", durationJson(rated#time)) ::
            ("fastest", durationJson(rated#fastest)) ::
            ("personalBest", durationJson(rated#personalBest)) :: Nil
        )

    def ratedToJson(rated: Rated): Json =
        JObject(
            ("time", durationJson(rated#time)) ::
            ("fastest", durationJson(rated#fastest)) ::
            ("personalBest", durationJson(rated#personalBest)) :: Nil
        )

    /// An absent time is the empty string, as it is in the laps file.
    def durationJson(time: Option[Duration]): Json =
        JString(match time {
            case Some(ms) => Util.Duration.format(ms)
            case None     => ""
        })

    pub def renderJsonl(laps: List[Placed]): String =
        laps
            |> List.map(lap -> "${Extra.renderOnOneLine(withPosition(Wec.toJson(lap#lap), lap#position))}\n")
            |> List.join("")

    def withPosition(lap: Json, position: Int32): Json =
        match lap {
            case JObject(fields) =>
                JObject(List.append(fields, ("position", JNumber(Int32.toBigDecimal(position))) :: Nil))
            case other => other
        }

}
