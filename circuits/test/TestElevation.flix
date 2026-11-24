/// The heights, as far as they are readable without asking: the form a batch of places is
/// asked with, the reading of what USGS 3DEP answers, and the kept file written and read
/// back. Which heights a survey's points are given is `TestSurvey`'s.
pub mod TestElevation {

    use Geodesy.Place

    def places(): List[Place] =
        {lat = 30.1335278, lon = -97.6422583} :: {lat = 30.13, lon = -97.64} :: Nil

    def sample(at: Int32, value: String): String =
        "{\"location\":{\"x\":-97.64,\"y\":30.13,\"spatialReference\":{\"wkid\":4326}},\"locationId\":${at},\"value\":\"${value}\",\"rasterId\":116248,\"resolution\":1}"

    def answer(samples: List[String]): String =
        "{\"samples\":[${String.intercalate(",", samples)}]}"

    // ------------------------------------------------------------------ the asking

    @Test
    def testAPlaceIsAskedAtTheDegreesItIsKeptUnder(): Unit \ Assert =
        let form = Elevation.ArcGis.form(places());
        Assert.assertTrue(String.startsWith({prefix = "geometry=%7B%22points%22%3A%5B%5B-97.6422583%2C30.1335278%5D%2C%5B-97.64%2C30.13%5D%5D"}, form));
        Assert.assertTrue(String.contains({substr = "&geometryType=esriGeometryMultipoint&"}, form));
        Assert.assertTrue(String.endsWith({suffix = "&f=json"}, form))

    @Test
    def testSamplesAreMatchedByTheIndexTheyWereAskedAt(): Unit \ Assert =
        // The service may answer in any order; a sample belongs to the place it was asked
        // for, not to the place standing where it came back.
        match Elevation.ArcGis.samplesOf("USGS 3DEP", places(), answer(sample(1, "163.531250000") :: sample(0, "154.860992432") :: Nil)) {
            case Err(problem) => Assert.assertTrueWithMsg(false, "the answer was refused: ${problem}")
            case Ok(read) =>
                Assert.assertTrue(List.map(each -> each#metres, read) == 154.860992432 :: 163.53125 :: Nil);
                Assert.assertTrue(List.map(each -> spelled(each#place), read) == List.map(spelled, places()));
                Assert.assertTrue(List.map(each -> each#resolution, read) == 1.0 :: 1.0 :: Nil)
        }

    @Test
    def testAPlaceWithNoHeightRefusesTheBatch(): Unit \ Assert =
        // `NoData` is a place outside the model, and a missing sample a place the service
        // dropped: either is a height the geometry cannot be drawn without.
        Assert.assertTrue(refused("holds no height at [-97.64,30.13]", Elevation.ArcGis.samplesOf("USGS 3DEP", places(), answer(sample(0, "154.8") :: sample(1, "NoData") :: Nil))));
        Assert.assertTrue(refused("answered no sample for [-97.64,30.13]", Elevation.ArcGis.samplesOf("USGS 3DEP", places(), answer(sample(0, "154.8") :: Nil))));
        // ArcGIS refuses a request as 200 with an `error` member.
        Assert.assertTrue(refused("refused the request", Elevation.ArcGis.samplesOf("USGS 3DEP", places(), "{\"error\":{\"code\":400,\"message\":\"Unable to complete operation.\"}}")))

    @Test
    def testAResolutionLeftOutIsNoMissingHeight(): Unit \ Assert =
        let bare = "{\"samples\":[{\"locationId\":0,\"value\":\"154.8\"},{\"locationId\":1,\"value\":\"155.1\"}]}";
        match Elevation.ArcGis.samplesOf("USGS 3DEP", places(), bare) {
            case Err(problem) => Assert.assertTrueWithMsg(false, problem)
            case Ok(read)     => Assert.assertTrue(List.map(each -> each#resolution, read) == 0.0 :: 0.0 :: Nil)
        }

    @Test
    def testAKeptDatasetIsKnownByItsService(): Unit \ Assert =
        // The smoothing a kept file is given follows from the source it names, so every
        // source is found again from its own dataset, and no two share a service.
        Assert.assertTrue(List.forAll(source -> Elevation.sourceOf(Elevation.datasetOf(source)) == Some(source), Elevation.sources()));
        Assert.assertTrue(Elevation.sourceOf({name = "n", license = "l", datum = "d", service = "https://example.org"}) == None)

    // ---------------------------------------------------------------- the other sources

    @Test
    def testIgnFranceAnswersOneHeightPerPlaceInOrder(): Unit \ Assert =
        Assert.assertTrue(String.contains({substr = "?lon=-97.6422583%7C-97.64&lat=30.1335278%7C30.13&resource=ign_lidar_hd_mnt_mono_wld"}, Elevation.Geopf.urlOf(places())));
        match Elevation.Geopf.samplesOf(places(), "{\"elevations\": [52.92, 55.39]}") {
            case Err(problem) => Assert.assertTrueWithMsg(false, problem)
            case Ok(read)     => Assert.assertTrue(List.map(each -> each#metres, read) == 52.92 :: 55.39 :: Nil)
        };
        // A place the model holds nothing for comes back as -99999.
        Assert.assertTrue(refused("holds no height at [-97.64,30.13]", Elevation.Geopf.samplesOf(places(), "{\"elevations\": [52.92, -99999]}")));
        Assert.assertTrue(refused("gave 1 heights for 2 places", Elevation.Geopf.samplesOf(places(), "{\"elevations\": [52.92]}")))

    @Test
    def testGsiAnswersAHeightAndTheModelItWasReadOff(): Unit \ Assert =
        let at = {lat = 35.371955, lon = 138.926737};
        match Elevation.Gsi.sampleOf(at, "{\"elevation\":580.9,\"hsrc\":\"1m\\uff08\\u30ec\\u30fc\\u30b6\\uff09\"}") {
            case Err(problem) => Assert.assertTrueWithMsg(false, problem)
            case Ok(read)     => Assert.assertTrue(read#metres == 580.9 and read#resolution == 1.0)
        };
        Assert.assertTrue(refused("holds no height", Elevation.Gsi.sampleOf(at, "{\"elevation\":\"-----\",\"hsrc\":\"-----\"}")))

    @Test
    def testIcgcAnswersThePixelAtThePlaceAsALineOfText(): Unit \ Assert =
        let at = {lat = 41.571101, lon = 2.262122};
        // Latitude first, the place at the middle of a box a thousandth of a degree across.
        Assert.assertTrue(String.contains({substr = "&BBOX=41.5706"}, Elevation.Icgc.urlOf(at)));
        Assert.assertTrue(String.contains({substr = "&WIDTH=101&HEIGHT=101&I=50&J=50&"}, Elevation.Icgc.urlOf(at)));
        match Elevation.Icgc.sampleOf(at, "@MET2m Stretch.Pixel Value; 120.430000; ") {
            case Err(problem) => Assert.assertTrueWithMsg(false, problem)
            case Ok(read)     => Assert.assertTrue(read#metres == 120.43 and read#resolution == 2.0)
        };
        Assert.assertTrue(refused("holds no height", Elevation.Icgc.sampleOf(at, "@MET2m Stretch.Pixel Value; NoData; ")))

    @Test
    def testWallonieAnswersThePixelThePlaceStandsIn(): Unit \ Assert =
        let at = {lat = 50.4431125, lon = 5.966015};
        // Longitude first, with no tolerance, on a map a thousandth of a degree across.
        Assert.assertTrue(String.contains({substr = "/identify?geometry=5.966015,50.4431125&"}, Elevation.Wallonie.urlOf(at)));
        Assert.assertTrue(String.contains({substr = "&tolerance=0&mapExtent=5.9655"}, Elevation.Wallonie.urlOf(at)));
        let answered = "{\"results\":[{\"layerId\":0,\"layerName\":\"Relief Wallonie - MNT 2021-2022 - 50cm\",\"displayFieldName\":\"\",\"attributes\":{\"Stretch.Pixel Value\":\"414.223145\"}}]}";
        match Elevation.Wallonie.sampleOf(at, answered) {
            case Err(problem) => Assert.assertTrueWithMsg(false, problem)
            case Ok(read)     => Assert.assertTrue(read#metres == 414.223145 and read#resolution == 0.5)
        };
        // A place outside Wallonia is answered with no result at all.
        Assert.assertTrue(refused("holds no height at [5.966015,50.4431125]", Elevation.Wallonie.sampleOf(at, "{\"results\":[]}")));
        Assert.assertTrue(refused("answered no results", Elevation.Wallonie.sampleOf(at, "{\"error\":{\"code\":400}}")))

    // ---------------------------------------------------------------- the kept file

    @Test
    def testTheKeptFileReadsBackAsItWasWritten(): Unit \ Assert =
        let samples = List.map(
            at -> {place = at, metres = 154.860992432, resolution = 1.0},
            places()
        );
        let text = Elevation.written(Elevation.datasetOf(Elevation.Source.Usgs3dep), samples);
        // One sample per line, at the degrees the geometry file spells them in.
        Assert.assertTrue(String.contains({substr = "\n{\"lon\":-97.6422583,\"lat\":30.1335278,\"metres\":154.860992432,\"resolution_m\":1},\n"}, text));
        match Elevation.read(text) {
            case Err(problem) => Assert.assertTrueWithMsg(false, "the kept file was refused: ${problem}")
            case Ok(kept) =>
                Assert.assertTrue(kept#dataset#name == Elevation.datasetOf(Elevation.Source.Usgs3dep)#name);
                Assert.assertTrue(kept#dataset#datum == "NAVD88");
                Assert.assertTrue(Map.get("[-97.64,30.13]", kept#heights) == Some(154.860992432))
        }

    @Test
    def testThePlacesFileIsHeadedAsTheKeptFileIsAndSpellsAPlaceALine(): Unit \ Assert =
        // `circuits/tools/pmsp-heights.py` copies the head into the kept file and reads the
        // places one per line, keeping each as it is spelled here.
        let text = Elevation.placesWritten(Elevation.datasetOf(Elevation.Source.PmspLidar2017), places());
        Assert.assertTrue(String.startsWith({prefix = "{\"source\": \"Mapa 3D Digital da Cidade"}, text));
        Assert.assertTrue(String.contains({substr = "\"service\": \"https://laz-m3dc-pmsp.s3.sa-east-1.amazonaws.com\", \"places\": [\n[-97.6422583,30.1335278],\n[-97.64,30.13]\n]}\n"}, text))

    @Test
    def testASampleMissingItsHeightIsRefusedNotSkipped(): Unit \ Assert =
        let text = "{\"source\": \"s\", \"license\": \"l\", \"datum\": \"d\", \"service\": \"u\", \"samples\": [\n{\"lon\":-97.64,\"lat\":30.13}\n]}";
        Assert.assertTrue(refused("sample 1 is not a place and a height", Elevation.read(text)));
        Assert.assertTrue(refused("names no datum", Elevation.read("{\"source\": \"s\", \"license\": \"l\", \"service\": \"u\", \"samples\": []}")))

    def spelled(at: Place): String = Geometry.Write.coordinate(at#lon, at#lat)

    def refused(phrase: String, result: Result[String, a]): Bool =
        match result {
            case Err(problem) => String.contains({substr = phrase}, problem)
            case Ok(_)        => false
        }
}
