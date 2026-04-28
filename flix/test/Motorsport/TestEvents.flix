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

}
