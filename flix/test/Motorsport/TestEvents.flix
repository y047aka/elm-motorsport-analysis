mod Motorsport.TestEvents {

    use Motorsport.Events

    @Test
    def testQatar(): Unit \ Assert =
        Assert.assertTrue(Events.displayName("qatar_1812km") == "Qatar 1812km")

    @Test
    def testImola(): Unit \ Assert =
        Assert.assertTrue(Events.displayName("imola_6h") == "6 Hours of Imola")

    @Test
    def testSpa(): Unit \ Assert =
        Assert.assertTrue(Events.displayName("spa_6h") == "6 Hours of Spa")

    @Test
    def testLeMans(): Unit \ Assert =
        Assert.assertTrue(Events.displayName("le_mans_24h") == "24 Hours of Le Mans")

    @Test
    def testCota(): Unit \ Assert =
        Assert.assertTrue(Events.displayName("cota_6h") == "Lone Star Le Mans")

    @Test
    def testFuji(): Unit \ Assert =
        Assert.assertTrue(Events.displayName("fuji_6h") == "6 Hours of Fuji")

    @Test
    def testBahrain(): Unit \ Assert =
        Assert.assertTrue(Events.displayName("bahrain_8h") == "8 Hours of Bahrain")

    @Test
    def testSaoPaulo(): Unit \ Assert =
        Assert.assertTrue(Events.displayName("sao_paulo_6h") == "6 Hours of São Paulo")

    @Test
    def testUnknownPassThrough(): Unit \ Assert =
        Assert.assertTrue(Events.displayName("unknown_event") == "unknown_event")

    @Test
    def testEveryRoundOnTheCalendarHasADirection(): Unit \ Assert =
        let ids = "qatar_1812km" :: "imola_6h" :: "spa_6h" :: "le_mans_24h" ::
                  "cota_6h" :: "fuji_6h" :: "bahrain_8h" :: "sao_paulo_6h" :: Nil;
        Assert.assertTrue(List.forAll(id -> not Option.isEmpty(Events.direction(id)), ids))

    @Test
    def testTheThreeCounterClockwiseRounds(): Unit \ Assert =
        use Motorsport.Circuit.Direction.Direction;
        Assert.assertTrue(Events.direction("imola_6h") == Some(Direction.CounterClockwise));
        Assert.assertTrue(Events.direction("cota_6h") == Some(Direction.CounterClockwise));
        Assert.assertTrue(Events.direction("sao_paulo_6h") == Some(Direction.CounterClockwise));
        Assert.assertTrue(Events.direction("fuji_6h") == Some(Direction.Clockwise))

    @Test
    def testUnknownRoundHasNoDirection(): Unit \ Assert =
        Assert.assertTrue(Option.isEmpty(Events.direction("unknown_event")))

}
