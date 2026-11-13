/// The circuit's proportions, which the Elm side reads straight off the
/// summary rather than working out again.
///
/// A stretch takes the share of the lap that its record does of every record
/// put together, so the track is drawn to how quick each part of it is. Read
/// off the whole file, so these are the records as the race left them and not
/// as they stood at any moment of it -- a stretch's share is how quick it was
/// at its quickest, and mid-race that answer is still moving.
pub mod Motorsport.Track {

    use oj::OrderedJson
    use oj::OrderedJson.Json.{JObject, JString, JNumber}
    use Util.Duration.Duration
    use Motorsport.Circuit.Circuit
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

    /// The whole lap, divided.
    ///
    /// `circuit` is the one thing here not read off the laps, which say nothing
    /// about it -- see `Motorsport.Events.circuit`. It is which ground the round
    /// was run on, which is what the drawing of it is chosen by. Which way
    /// round the drawing runs is the drawing's own affair: a drawn circuit
    /// carries it in its geometry, and the ring has no geometry to ask and runs
    /// clockwise -- so São Paulo and Imola are drawn the other way from the way
    /// their cars went.
    pub type alias Track = {
        circuit     = Option[Circuit],
        sectors     = List[(Sector, Share)],
        miniSectors = Option[List[(MiniSectorId, Share)]]
    }

    /// Which grain the lap is divided at follows from what the feed carries,
    /// rather than from a list of event names: `miniSectorTime` is given only
    /// for a round that measured them.
    pub def fromFastest(
        circuit: Option[Circuit],
        sectorTime: Sector -> Option[Duration],
        miniSectorTime: Option[MiniSectorId -> Option[Duration]]
    ): Track =
        match miniSectorTime {
            case Some(timeOf) => atMiniSectorGrain(circuit, timeOf)
            case None         => atSectorGrain(circuit, sectorTime)
        }

    def atSectorGrain(
        circuit: Option[Circuit],
        sectorTime: Sector -> Option[Duration]
    ): Track =
        let ratio = ratiosOver(Sector.all(), sectorTime);
        {
            circuit     = circuit,
            sectors     = sharesOver(ratio, Sector.all()),
            miniSectors = None
        }

    def atMiniSectorGrain(
        circuit: Option[Circuit],
        miniSectorTime: MiniSectorId -> Option[Duration]
    ): Track =
        let miniRatio = ratiosOver(MiniSector.all(), miniSectorTime);
        let sectorRatio = sector ->
            MiniSector.all()
                |> List.filter(id -> MiniSector.sectorOf(id) == sector)
                |> List.map(miniRatio)
                |> sum;
        {
            circuit     = circuit,
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

    pub def toJson(track: Track): OrderedJson.Json =
        let circuit = match track#circuit {
            case None     => Nil
            case Some(c)  => ("circuit", JString(Circuit.jsonValue(c))) :: Nil
        };
        let sectors = track#sectors |> List.map(match (sector, share) -> (Sector.jsonKey(sector), shareToJson(share)));
        let miniSectors = match track#miniSectors {
            case None       => Nil
            case Some(list) =>
                let entries = list |> List.map(match (id, share) -> (MiniSector.jsonKey(id), shareToJson(share)));
                ("miniSectors", JObject(entries)) :: Nil
        };
        JObject(List.append(circuit, ("sectors", JObject(sectors)) :: miniSectors))

    def shareToJson(share: Share): OrderedJson.Json =
        JObject(
            ("start", ratio(share#start)) ::
            ("share", ratio(share#share)) ::
            Nil
        )

    /// `Float64.tryToBigDecimal` is `new BigDecimal(x)`, which spells `0.20739060549440685` as `0.207390605494406854436562070986838079988956451416015625`.
    /// `Float64.toString` is `Double.toString`, and every finite value it prints `new BigDecimal` parses, which is what leaves the `None` branch unreachable.
    /// `NaN` and `Infinity` are the two it prints that `new BigDecimal` refuses, and no share is one: `ratiosOver` divides only where the total is non-zero.
    /// The number reaches the file spelled by `BigDecimal.toPlainString`, so a share small enough for `Double.toString` to write `9.0E-4` arrives as `0.0009` instead.
    def ratio(x: Float64): OrderedJson.Json =
        match BigDecimal.fromString("${Float64.toString(x)}") {
            case Some(d) => JNumber(d)
            case None    => unreachable!()
        }

}
