/// The grid order itself, read off cars given directly. What a round's cars
/// are is `Round.Summary`'s to count and `Round.TestSummary`'s to check;
/// the decisions made once they are counted are these.
mod Motorsport.TestMetadata {

    use Motorsport.Car.Car
    use Motorsport.Metadata
    use Motorsport.Metadata.Basis
    use Motorsport.Metadata.CarBuild
    use Util.Duration

    def build(carNumber: String, lap1S1: Option[Int32], lap1Elapsed: Option[Int32]): CarBuild =
        let car: Car = {
            carNumber    = carNumber,
            drivers      = Nil,
            class        = "HYPERCAR",
            group        = "H",
            team         = "Team",
            manufacturer = "Maker"
        };
        {
            car         = car,
            lap1S1      = Option.map(Duration.fromMillis, lap1S1),
            lap1Elapsed = Option.map(Duration.fromMillis, lap1Elapsed)
        }

    def order(builds: List[CarBuild]): List[String] =
        Metadata.estimateGrid(builds)#entries |> List.map(entry -> entry#car#carNumber)

    @Test
    def theFirstSplitIsTheBasisWhenEveryStarterTurnedOne(): Unit \ Assert =
        let builds = build("7", Some(30000), Some(100000)) :: build("8", Some(29000), Some(101000)) :: Nil;
        Assert.assertTrue(Metadata.estimateGrid(builds)#basis == Basis.Lap1S1);
        Assert.assertTrue(order(builds) == "8" :: "7" :: Nil)

    /// One starter without a first split takes the whole field off S1: a split
    /// weighed against another car's whole lap would order them by their units.
    @Test
    def oneStarterWithoutASplitTakesTheFieldOffThem(): Unit \ Assert =
        let builds = build("7", Some(30000), Some(100000)) :: build("8", None, Some(99000)) :: Nil;
        Assert.assertTrue(Metadata.estimateGrid(builds)#basis == Basis.Lap1Elapsed);
        Assert.assertTrue(order(builds) == "8" :: "7" :: Nil)

    @Test
    def aFieldThatTurnedNoFirstLapHasNoBasisAndIsStillPlaced(): Unit \ Assert =
        let builds = build("7", None, None) :: build("8", Some(30000), None) :: Nil;
        Assert.assertTrue(Metadata.estimateGrid(builds)#basis == Basis.Unknown);
        Assert.assertTrue(order(builds) == "7" :: "8" :: Nil)

    @Test
    def anEqualReadingBreaksOnTheWholeFirstLap(): Unit \ Assert =
        let builds = build("7", Some(30000), Some(101000)) :: build("8", Some(30000), Some(100000)) :: Nil;
        Assert.assertTrue(order(builds) == "8" :: "7" :: Nil)

    /// Any total order settles the last tie, and car numbers are compared as
    /// the strings they are: Le Mans runs #7 alongside #007.
    @Test
    def anEqualLapBreaksOnTheCarNumberAsText(): Unit \ Assert =
        let builds = build("7", Some(30000), Some(100000)) :: build("007", Some(30000), Some(100000)) :: Nil;
        Assert.assertTrue(order(builds) == "007" :: "7" :: Nil)

    /// It did start the race, and the back is where being wrong costs least.
    @Test
    def aCarWithNoFirstLapIsPlacedRatherThanDropped(): Unit \ Assert =
        let builds = build("7", None, None) :: build("8", Some(30000), Some(100000)) :: Nil;
        Assert.assertTrue(order(builds) == "8" :: "7" :: Nil)

    @Test
    def positionsAreNumberedFromOneInGridOrder(): Unit \ Assert =
        let builds = build("7", Some(31000), Some(100000)) :: build("8", Some(30000), Some(100000)) :: Nil;
        Assert.assertTrue(
            Metadata.estimateGrid(builds)#entries |> List.map(entry -> entry#position) == 1 :: 2 :: Nil
        )

}
