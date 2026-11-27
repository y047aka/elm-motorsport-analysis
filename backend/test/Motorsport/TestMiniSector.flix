pub mod Motorsport.TestMiniSector {

    use Motorsport.MiniSector
    use Motorsport.MiniSector.MiniSectorId

    @Test
    def testCsvNamesPreserveHyphens(): Unit \ Assert =
        // Flix identifier `A7_1` / `A8_1` must map to the hyphenated
        // CSV columns `A7-1_*` / `A8-1_*`.
        Assert.assertTrue(MiniSector.csvName(MiniSectorId.A7_1) == "A7-1");
        Assert.assertTrue(MiniSector.csvName(MiniSectorId.A8_1) == "A8-1")

    @Test
    def testAllIdsHaveDistinctNames(): Unit \ Assert =
        // The name is the key the file names the mini-sector by, and the Elm
        // side joins its lists on it, so a name two ids share would quietly
        // merge two stretches of the lap.
        let names = MiniSector.all() |> List.map(MiniSector.csvName);
        Assert.assertTrue(List.length(List.distinct(names)) == 15)

}
