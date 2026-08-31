/// The circuit's proportions, which the Elm side reads straight off the
/// summary rather than working out again.
///
/// A stretch takes the share of the lap that its record does of every record
/// put together, so the track is drawn to how quick each part of it is. Read
/// off the whole file, so these are the records as the race left them and not
/// as they stood at any moment of it -- a stretch's share is how quick it was
/// at its quickest, and mid-race that answer is still moving.
mod Motorsport.Track {

    use Util.Duration.Duration
    use Util.Json.Encode
    use Util.Json.Encode.JsonValue.{JsonObject, JsonFloat, JsonString}
    use Motorsport.Circuit.Direction
    use Motorsport.Circuit.Direction.Direction
    use Motorsport.MiniSector
    use Motorsport.MiniSector.MiniSectorId
    use Motorsport.Sector
    use Motorsport.Sector.Sector

    /// Where a stretch begins and how much of the lap it takes, both as
    /// fractions of the whole.
    pub type alias Share = {
        start = Float64,
        share = Float64
    }

    /// The whole lap, divided, and which way round it is driven. Both grains
    /// cover the same lap, so a car can be placed by either.
    ///
    /// `direction` is the one thing here not read off the laps, which say
    /// nothing about it -- see `Motorsport.Events.direction`.
    pub type alias Track = {
        direction   = Option[Direction],
        sectors     = List[(Sector, Share)],
        miniSectors = Option[List[(MiniSectorId, Share)]]
    }

    /// Which grain the lap is divided at follows from what the feed carries,
    /// rather than from a list of event names: `miniSectorTime` is given only
    /// for a round that measured them.
    pub def fromFastest(
        direction: Option[Direction],
        sectorTime: Sector -> Option[Duration],
        miniSectorTime: Option[MiniSectorId -> Option[Duration]]
    ): Track =
        match miniSectorTime {
            case Some(timeOf) => atMiniSectorGrain(direction, timeOf)
            case None         => atSectorGrain(direction, sectorTime)
        }

    def atSectorGrain(direction: Option[Direction], sectorTime: Sector -> Option[Duration]): Track =
        let ratio = ratiosOver(Sector.all(), sectorTime);
        {
            direction   = direction,
            sectors     = sharesOver(ratio, Sector.all()),
            miniSectors = None
        }

    def atMiniSectorGrain(direction: Option[Direction], miniSectorTime: MiniSectorId -> Option[Duration]): Track =
        let miniRatio = ratiosOver(MiniSector.all(), miniSectorTime);
        let sectorRatio = sector ->
            MiniSector.all()
                |> List.filter(id -> MiniSector.sectorOf(id) == sector)
                |> List.map(miniRatio)
                |> sum;
        {
            direction   = direction,
            sectors     = sharesOver(sectorRatio, Sector.all()),
            miniSectors = Some(sharesOver(miniRatio, MiniSector.all()))
        }

    def ratiosOver(order: List[a], timeOf: a -> Option[Duration]): a -> Float64 =
        let total = order |> List.filterMap(timeOf) |> List.map(Util.Duration.millis) |> List.sum |> Int32.toFloat64;
        id ->
            if (total == 0.0f64)
                1.0f64 / Int32.toFloat64(List.length(order))
            else
                Int32.toFloat64(timeOf(id) |> Option.map(Util.Duration.millis) |> Option.getWithDefault(0)) / total

    def sharesOver(ratio: a -> Float64, order: List[a]): List[(a, Share)] with Eq[a] =
        order |> List.map(id -> (id, { start = startOf(ratio, order, id), share = ratio(id) }))

    def startOf(ratio: a -> Float64, order: List[a], id: a): Float64 with Eq[a] =
        order |> List.takeWhile(other -> other != id) |> List.map(ratio) |> sum

    def sum(xs: List[Float64]): Float64 =
        List.foldLeft((acc, x) -> acc + x, 0.0f64, xs)

    pub def toJson(track: Track): Encode.JsonValue =
        let direction = match track#direction {
            case None    => Nil
            case Some(d) => ("direction", JsonString(Direction.jsonValue(d))) :: Nil
        };
        let sectors = track#sectors |> List.map(match (sector, share) -> (Sector.jsonKey(sector), shareToJson(share)));
        let miniSectors = match track#miniSectors {
            case None       => Nil
            case Some(list) =>
                let entries = list |> List.map(match (id, share) -> (MiniSector.jsonKey(id), shareToJson(share)));
                ("miniSectors", JsonObject(entries)) :: Nil
        };
        JsonObject(List.append(direction, ("sectors", JsonObject(sectors)) :: miniSectors))

    def shareToJson(share: Share): Encode.JsonValue =
        JsonObject(
            ("start", JsonFloat(share#start)) ::
            ("share", JsonFloat(share#share)) ::
            Nil
        )

}
