mod Motorsport.TestMiniSector {

    use Motorsport.MiniSector
    use Motorsport.MiniSector.MiniSectorId

    @Test
    def testCsvNamesPreserveHyphens(): Unit \ Assert =
        // Flix identifier `A7_1` / `A8_1` must map to the hyphenated
        // CSV columns `A7-1_*` / `A8-1_*`.
        Assert.assertTrue(MiniSector.csvName(MiniSectorId.A7_1) == "A7-1");
        Assert.assertTrue(MiniSector.csvName(MiniSectorId.A8_1) == "A8-1")

    @Test
    def testJsonKeysPreserveUnderscores(): Unit \ Assert =
        // JSON keys keep the underscore (matches Elm `Motorsport.Lap.MiniSectors`).
        Assert.assertTrue(MiniSector.jsonKey(MiniSectorId.A7_1) == "a7_1");
        Assert.assertTrue(MiniSector.jsonKey(MiniSectorId.A8_1) == "a8_1")

    @Test
    def testAllIdsHaveDistinctJsonKeys(): Unit \ Assert =
        let keys = MiniSector.all() |> List.map(MiniSector.jsonKey);
        Assert.assertTrue(List.length(List.distinct(keys)) == 15)

}
