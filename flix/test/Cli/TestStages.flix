mod Cli.TestStages {

    use Cli.Stages
    use Util.Csv.Decode
    use Util.Csv.Decode.FieldNames
    use RawLap.RawLap

    def header(): String =
        "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS"

    /// Rust 側 integration.rs L500-505 の create_test_csv_data と同等の 3 行データ。
    /// セミコロン区切り、22 列以上のフィールド。
    def sampleRawLaps(): List[RawLap] =
        let csv =
            header() + "\n" +
            "12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:00.000;;;;310.5;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;;;;\n" +
            "7;1;1;1:33.291;0;;23.119;0;29.188;0;40.984;0;175.0;1:33.291;11:02:00.000;;;;298.6;Kamui KOBAYASHI;;HYPERCAR;H;Toyota Gazoo Racing;Toyota;;;;\n" +
            "12;2;2;1:32.245;1;;22.500;1;29.100;1;40.645;1;165.2;3:07.610;11:03:32.000;;;;312.0;Robin FRIJNS;;HYPERCAR;H;Hertz Team JOTA;Porsche;;;;";
        match Decode.decodeCustom(
            {fieldSeparator = ';'},
            FieldNames.FieldNamesFromFirstRow,
            RawLap.decoder(),
            csv
        ) {
            case Ok(rs) => rs
            case Err(_) => unreachable!()
        }

    @Test
    def testProcessCountsLaps(): Unit \ Assert =
        let out = Stages.process("le_mans_24h", sampleRawLaps());
        Assert.assertTrue(out#lapCount == 3)

    @Test
    def testProcessRendersMetadataJson(): Unit \ Assert =
        let out = Stages.process("le_mans_24h", sampleRawLaps());
        let json = out#metadataJson;
        Assert.assertTrue(String.contains({substr = "\"24 Hours of Le Mans\""}, json));
        Assert.assertTrue(String.contains({substr = "\"startingGrid\""}, json));
        Assert.assertTrue(String.contains({substr = "\"carNumber\": \"7\""}, json));
        Assert.assertTrue(String.contains({substr = "\"carNumber\": \"12\""}, json))

    @Test
    def testProcessRendersLapsJson(): Unit \ Assert =
        let out = Stages.process("le_mans_24h", sampleRawLaps());
        let json = out#lapsJson;
        Assert.assertTrue(String.contains({substr = "\"lapNumber\": 1"}, json));
        Assert.assertTrue(String.contains({substr = "\"driverName\": \"Will STEVENS\""}, json));
        Assert.assertTrue(String.contains({substr = "\"driverName\": \"Kamui KOBAYASHI\""}, json));
        Assert.assertTrue(String.contains({substr = "\"driverName\": \"Robin FRIJNS\""}, json))

    @Test
    def testProcessEmptyInputProducesEmptyArrays(): Unit \ Assert =
        let out = Stages.process("le_mans_24h", Nil);
        Assert.assertTrue(out#lapCount == 0);
        Assert.assertTrue(String.contains({substr = "\"startingGrid\": []"}, out#metadataJson));
        Assert.assertTrue(out#lapsJson == "[]")

}
