/// How the lap divides, given the records it divides on. Which lap set those
/// records is `Round.Summary`'s to find and `Round.TestTrack`'s to check.
mod Motorsport.TestTrack {

    use Motorsport.Circuit.Direction.Direction
    use Motorsport.MiniSector
    use Motorsport.MiniSector.MiniSectorId
    use Motorsport.Sector.Sector
    use Motorsport.Track
    use Motorsport.Track.Share
    use Util.Duration
    use Util.Duration.Duration

    def sectors(s1: Option[Int32], s2: Option[Int32], s3: Option[Int32]): Sector -> Option[Duration] =
        sector -> Option.map(Duration.fromMillis, match sector {
            case Sector.S1 => s1
            case Sector.S2 => s2
            case Sector.S3 => s3
        })

    def evenMiniSectors(each: Int32): Option[MiniSectorId -> Option[Duration]] =
        Some(_ -> Some(Duration.fromMillis(each)))

    def shareOf(sector: Sector, track: Track.Track): Option[Share] =
        track#sectors |> List.findLeft(match (other, _) -> other == sector) |> Option.map(match (_, share) -> share)

    def miniShareOf(id: MiniSectorId, track: Track.Track): Option[Share] =
        track#miniSectors
            |> Option.flatMap(list -> List.findLeft(match (other, _) -> other == id, list))
            |> Option.map(match (_, share) -> share)

    def closeTo(expected: Float64, actual: Float64): Bool =
        Float64.abs(expected - actual) < 0.000001f64

    def isShare(start: Float64, share: Float64, actual: Option[Share]): Bool =
        match actual {
            case None    => false
            case Some(s) => closeTo(start, s#start) and closeTo(share, s#share)
        }

    @Test
    def aStretchTakesTheShareItsRecordIsOfTheLap(): Unit \ Assert =
        let track = Track.fromFastest(Some(Direction.Clockwise), sectors(Some(20000), Some(30000), Some(50000)), None);
        Assert.assertTrue(isShare(0.0f64, 0.2f64, shareOf(Sector.S1, track)));
        Assert.assertTrue(isShare(0.2f64, 0.3f64, shareOf(Sector.S2, track)));
        Assert.assertTrue(isShare(0.5f64, 0.5f64, shareOf(Sector.S3, track)))

    @Test
    def aStretchWithNoRecordTakesNoShare(): Unit \ Assert =
        let track = Track.fromFastest(Some(Direction.Clockwise), sectors(Some(20000), None, Some(30000)), None);
        Assert.assertTrue(isShare(0.0f64, 0.4f64, shareOf(Sector.S1, track)));
        Assert.assertTrue(isShare(0.4f64, 0.0f64, shareOf(Sector.S2, track)));
        Assert.assertTrue(isShare(0.4f64, 0.6f64, shareOf(Sector.S3, track)))

    /// Nothing is known about how long each stretch is until a lap has been
    /// round, so the lap is still divided, in equal parts.
    @Test
    def noRecordsAtAllDividesTheLapEvenly(): Unit \ Assert =
        let track = Track.fromFastest(None, sectors(None, None, None), None);
        Assert.assertTrue(isShare(0.0f64, 1.0f64 / 3.0f64, shareOf(Sector.S1, track)));
        Assert.assertTrue(isShare(2.0f64 / 3.0f64, 1.0f64 / 3.0f64, shareOf(Sector.S3, track)));
        Assert.assertTrue(Option.isEmpty(track#miniSectors))

    /// Fifteen equal mini-sectors, grouped 3 / 4 / 8. The sectors' own records
    /// say something else entirely and are not consulted.
    @Test
    def aSectorIsWhatItsMiniSectorsTakeBetweenThem(): Unit \ Assert =
        let track = Track.fromFastest(
            Some(Direction.Clockwise),
            sectors(Some(1000), Some(1000), Some(1000)),
            evenMiniSectors(1000)
        );
        Assert.assertTrue(isShare(0.0f64, 3.0f64 / 15.0f64, shareOf(Sector.S1, track)));
        Assert.assertTrue(isShare(3.0f64 / 15.0f64, 4.0f64 / 15.0f64, shareOf(Sector.S2, track)));
        Assert.assertTrue(isShare(7.0f64 / 15.0f64, 8.0f64 / 15.0f64, shareOf(Sector.S3, track)));
        Assert.assertTrue(isShare(0.0f64, 1.0f64 / 15.0f64, miniShareOf(MiniSectorId.SCL2, track)));
        Assert.assertTrue(isShare(14.0f64 / 15.0f64, 1.0f64 / 15.0f64, miniShareOf(MiniSectorId.FL, track)))

}
