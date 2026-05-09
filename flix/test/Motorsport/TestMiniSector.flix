mod Motorsport.TestMiniSector {

    use Motorsport.MiniSector
    use Motorsport.MiniSector.MiniSectorId

    @Test
    def testAllHasFifteenIds(): Unit \ Assert =
        Assert.assertTrue(List.length(MiniSector.all()) == 15)

    @Test
    def testAllStartsWithS1MiniSectors(): Unit \ Assert =
        // S1 = SCL2, Z4, IP1 (matches Motorsport.Circuit.LeMans.layout.s1).
        match List.take(3, MiniSector.all()) {
            case MiniSectorId.SCL2 :: MiniSectorId.Z4 :: MiniSectorId.IP1 :: Nil =>
                Assert.assertTrue(true)
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testAllEndsWithFinishLine(): Unit \ Assert =
        match List.last(MiniSector.all()) {
            case Some(MiniSectorId.FL) => Assert.assertTrue(true)
            case _                     => Assert.assertTrue(false)
        }

    @Test
    def testCsvNamesPreserveHyphens(): Unit \ Assert =
        // The Flix identifier underscore in A7_1 / A8_1 must map to a hyphen
        // in the CSV column name (the actual columns are A7-1_time / A8-1_time).
        Assert.assertTrue(MiniSector.csvName(MiniSectorId.A7_1) == "A7-1");
        Assert.assertTrue(MiniSector.csvName(MiniSectorId.A8_1) == "A8-1");
        Assert.assertTrue(MiniSector.csvName(MiniSectorId.SCL2) == "SCL2");
        Assert.assertTrue(MiniSector.csvName(MiniSectorId.FORDOUT) == "FORDOUT");
        Assert.assertTrue(MiniSector.csvName(MiniSectorId.FL) == "FL")

    @Test
    def testJsonKeysPreserveUnderscores(): Unit \ Assert =
        // JSON keys lowercase the CSV name and preserve underscores
        // (matches Motorsport.Lap.MiniSectors field names on the Elm side).
        Assert.assertTrue(MiniSector.jsonKey(MiniSectorId.A7_1) == "a7_1");
        Assert.assertTrue(MiniSector.jsonKey(MiniSectorId.A8_1) == "a8_1");
        Assert.assertTrue(MiniSector.jsonKey(MiniSectorId.SCL2) == "scl2");
        Assert.assertTrue(MiniSector.jsonKey(MiniSectorId.PORIN) == "porin");
        Assert.assertTrue(MiniSector.jsonKey(MiniSectorId.FL) == "fl")

    @Test
    def testAllIdsHaveDistinctJsonKeys(): Unit \ Assert =
        let keys = MiniSector.all() |> List.map(MiniSector.jsonKey);
        Assert.assertTrue(List.length(List.distinct(keys)) == 15)

}
