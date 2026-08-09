/// The circuit's proportions: how much of the lap each stretch of it takes,
/// and where round the lap that stretch begins.
///
/// A stretch takes the share of the lap that its record does of every record
/// put together -- so the track is drawn to how quick each part of it is. The
/// rule and the numbers it produces are what the Elm side reads straight off
/// the summary; see `Motorsport.Chart.Tracker.Config` there.
///
/// Read off the whole file, so these are the records as the race left them,
/// not as they stood at any moment of it: a stretch's share is how quick it
/// was at its quickest, and mid-race that answer is still moving.
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
    use Motorsport.Wec.RawLap

    /// One stretch of the lap: where it begins and how much of the lap it
    /// takes, both as fractions of the whole. Which stretch it is belongs to
    /// the key it is filed under.
    pub type alias Share = {
        start = Float64,
        share = Float64
    }

    /// The whole lap, divided, and which way round it is driven. Both grains
    /// cover the same lap, so a car can be placed by either; `miniSectors` is
    /// `None` on the rounds whose feed does not split the lap that far.
    ///
    /// `direction` is the one thing here that is not read off the laps, which
    /// say nothing about it -- see `Motorsport.Events.direction`, and its
    /// `None` for a round this CLI has not been told about.
    pub type alias Track = {
        direction   = Option[Direction],
        sectors     = List[(Sector, Share)],
        miniSectors = Option[List[(MiniSectorId, Share)]]
    }

    /// Which grain the lap is divided at is decided by what the feed carries,
    /// not by a list of event names: a round whose file splits the lap into
    /// mini-sectors is drawn at that grain.
    pub def fromRawLaps(direction: Option[Direction], rawLaps: List[RawLap]): Track =
        if (List.exists(hasMiniSectors, rawLaps))
            atMiniSectorGrain(direction, rawLaps)
        else
            atSectorGrain(direction, rawLaps)

    def hasMiniSectors(lap: RawLap): Bool =
        match lap#miniSectors {
            case Some(_) => true
            case None    => false
        }

    def atSectorGrain(direction: Option[Direction], rawLaps: List[RawLap]): Track =
        let ratio = ratiosOver(Sector.all(), sector -> fastest(sectorTime(sector), rawLaps));
        {
            direction   = direction,
            sectors     = sharesOver(ratio, Sector.all()),
            miniSectors = None
        }

    def atMiniSectorGrain(direction: Option[Direction], rawLaps: List[RawLap]): Track =
        let miniRatio = ratiosOver(MiniSector.all(), id -> fastest(miniSectorTime(id), rawLaps));
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

    /// What share of the lap each stretch's record is of every record put
    /// together. A stretch no lap has set a time for counts as nothing, and
    /// with no records at all the stretches divide the lap evenly between them.
    def ratiosOver(order: List[a], timeOf: a -> Option[Duration]): a -> Float64 =
        let total = order |> List.filterMap(timeOf) |> List.map(Util.Duration.millis) |> List.sum |> Int32.toFloat64;
        id ->
            if (total == 0.0f64)
                1.0f64 / Int32.toFloat64(List.length(order))
            else
                Int32.toFloat64(timeOf(id) |> Option.map(Util.Duration.millis) |> Option.getWithDefault(0)) / total

    /// Lay the stretches out end to end from the line, each taking the share
    /// its ratio gives it.
    def sharesOver(ratio: a -> Float64, order: List[a]): List[(a, Share)] with Eq[a] =
        order |> List.map(id -> (id, { start = startOf(ratio, order, id), share = ratio(id) }))

    def startOf(ratio: a -> Float64, order: List[a], id: a): Float64 with Eq[a] =
        order |> List.takeWhile(other -> other != id) |> List.map(ratio) |> sum

    def sum(xs: List[Float64]): Float64 =
        List.foldLeft((acc, x) -> acc + x, 0.0f64, xs)

    def fastest(timeOf: RawLap -> Option[Duration], rawLaps: List[RawLap]): Option[Duration] =
        rawLaps |> List.filterMap(timeOf) |> List.minimum

    def sectorTime(sector: Sector): RawLap -> Option[Duration] =
        lap -> match sector {
            case Sector.S1 => lap#s1#value
            case Sector.S2 => lap#s2#value
            case Sector.S3 => lap#s3#value
        }

    /// A mini-sector time is only trusted on a lap that has a lap time. The
    /// feed writes an unrecorded lap out as `0.000`, and the mini-sectors of
    /// such a lap are not a lap of the circuit either.
    def miniSectorTime(id: MiniSectorId): RawLap -> Option[Duration] =
        lap ->
            if (Util.Duration.millis(lap#lapTime) == 0)
                None
            else
                lap#miniSectors
                    |> Option.flatMap(list -> List.findLeft(match (other, _) -> other == id, list))
                    |> Option.flatMap(match (_, sector) -> sector#time)

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
