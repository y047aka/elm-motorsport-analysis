mod Round.TestRender {

    use Round.Render
    use Round.Summary
    use Round.TestSupport
    use Util.Csv.Decode
    use Util.Csv.Decode.FieldNames
    use Motorsport.Calendar.Entry
    use Motorsport.Metadata
    use Motorsport.Wec
    use Motorsport.Wec.RawLap

    def leMans(): Entry = { season = 2025, id = "le_mans_24h", date = "2025-06-14" }

    def header(): String =
        "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS"

    /// The three rows Rust's create_test_csv_data uses (integration.rs L500-505):
    /// semicolon-separated, 22 columns or more.
    def sampleRawLaps(): List[RawLap] =
        let csv =
            header() + "\n" +
            "12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:00.000;;;;310.5;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;;;\n" +
            "7;1;1;1:33.291;0;;23.119;0;29.188;0;40.984;0;175.0;1:33.291;11:02:00.000;;;;298.6;Kamui KOBAYASHI;;HYPERCAR;H;Toyota Gazoo Racing;Toyota;GF;;;\n" +
            "12;2;2;1:32.245;1;;22.500;1;29.100;1;40.645;1;165.2;3:07.610;11:03:32.000;;;;312.0;Robin FRIJNS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;;;";
        match Decode.decodeCustom(
            {fieldSeparator = ';'},
            FieldNames.FieldNamesFromFirstRow,
            Wec.decoder(),
            csv
        ) {
            case Ok(rs) => rs
            case Err(_) => unreachable!()
        }

    def summaryOf(laps: List[RawLap]): Metadata.Metadata \ IO =
        TestSupport.onRound(leMans(), laps, () -> Summary.read(leMans()))

    @Test
    def testRenderMetadataRendersTheRoundsSummary(): Unit \ {Assert, IO} =
        let json = Render.renderMetadata(summaryOf(sampleRawLaps()));
        Assert.assertTrue(String.contains({substr = "\"24 Hours of Le Mans\""}, json));
        Assert.assertTrue(String.contains({substr = "\"startingGrid\""}, json));
        Assert.assertTrue(String.contains({substr = "\"carNumber\": \"7\""}, json));
        Assert.assertTrue(String.contains({substr = "\"carNumber\": \"12\""}, json))

    /// A round with no laps still has a summary, and it still renders.
    @Test
    def testRenderMetadataOfARoundWithNoLaps(): Unit \ {Assert, IO} =
        let json = Render.renderMetadata(summaryOf(Nil));
        Assert.assertTrue(String.contains({substr = "\"basis\": \"unknown\""}, json));
        Assert.assertTrue(String.contains({substr = "\"entries\": []"}, json))

    @Test
    def testRenderJsonlRendersEveryLap(): Unit \ Assert =
        let jsonl = Render.renderJsonl(sampleRawLaps());
        Assert.assertTrue(String.contains({substr = "\"lapNumber\": 1"}, jsonl));
        Assert.assertTrue(String.contains({substr = "\"driverName\": \"Will STEVENS\""}, jsonl));
        Assert.assertTrue(String.contains({substr = "\"driverName\": \"Kamui KOBAYASHI\""}, jsonl));
        Assert.assertTrue(String.contains({substr = "\"driverName\": \"Robin FRIJNS\""}, jsonl))

    @Test
    def testEveryLapIsOneLine(): Unit \ Assert =
        let jsonl = Render.renderJsonl(sampleRawLaps());
        let lines = String.splitOn({substr = "\n"}, jsonl) |> List.filter(line -> line != "");
        Assert.assertTrue(String.endsWith({suffix = "\n"}, jsonl));
        Assert.assertTrue(List.length(lines) == 3);
        Assert.assertTrue(List.forAll(
            line -> String.startsWith({prefix = "{ "}, line) and String.endsWith({suffix = " }"}, line),
            lines
        ))

    @Test
    def testRenderJsonlOfNoLapsIsEmpty(): Unit \ Assert =
        Assert.assertTrue(Render.renderJsonl(Nil) == "")

}
