mod TestRawLap {

    use Util.Csv.Decode
    use Util.Csv.Decode.{FieldNames, Error}
    use Util.HourClock.Hour
    use Util.Json
    use RawLap.RawLap

    def header(): String =
        "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS"

    /// Decodes a single semicolon-separated CSV line (without header) and
    /// pulls the first record out of the result. The header row is prepended
    /// automatically so the decoder can resolve field names.
    def decodeOne(line: String): Result[Error, RawLap] =
        match Decode.decodeCustom(
            {fieldSeparator = ';'},
            FieldNames.FieldNamesFromFirstRow,
            RawLap.decoder(),
            header() + "\n" + line
        ) {
            case Ok(r :: _) => Ok(r)
            case Ok(Nil)    => Err(Error.DecodingErrors(Nil))
            case Err(e)     => Err(e)
        }

    @Test
    def testFromCsvRowValid(): Unit \ Assert =
        match decodeOne("12;1;3;2:41.963;0;;41.805;0;1:03.483;0;56.675;0;101.4;6:10.938;11:06:38.429;0:41.805;1:03.483;0:56.675;88.5;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;41.805;63.483;56.675;") {
            case Ok(r) =>
                Assert.assertTrue(r#car#carNumber == "12");
                Assert.assertTrue(r#driver#driverNumber == 1);
                Assert.assertTrue(r#lapNumber == 3);
                Assert.assertTrue(r#lapTime == "2:41.963");
                Assert.assertTrue(r#lapImprovement == RawLap.Improvement.None);
                Assert.assertTrue(r#crossingFinishLineInPit == "");
                Assert.assertTrue(r#s1#value == Some(41805));
                Assert.assertTrue(r#s1#improvement == RawLap.Improvement.None);
                Assert.assertTrue(r#s2#value == Some(63483));
                Assert.assertTrue(r#s3#value == Some(56675));
                Assert.assertTrue(r#kph == "101.4");
                Assert.assertTrue(r#elapsed == "6:10.938");
                Assert.assertTrue(r#hour == Hour.Hour(39998429));
                Assert.assertTrue(r#topSpeed == "88.5");
                Assert.assertTrue(r#driver#driverName == "Will STEVENS");
                Assert.assertTrue(r#pitTime == "");
                Assert.assertTrue(r#car#class == "HYPERCAR");
                Assert.assertTrue(r#car#group == "H");
                Assert.assertTrue(r#car#team == "Hertz Team JOTA");
                Assert.assertTrue(r#car#manufacturer == "Porsche")
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testFromCsvRowStripsTopSpeedTrailingDotZero(): Unit \ Assert =
        match decodeOne("12;1;3;2:41.963;0;;41.805;0;1:03.483;0;56.675;0;101.4;6:10.938;11:06:38.429;0:41.805;1:03.483;0:56.675;150.0;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;41.805;63.483;56.675;") {
            case Ok(r)  => Assert.assertTrue(r#topSpeed == "150")
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testToJsonRendersWholeKphAsInt(): Unit \ Assert =
        // KPH "86.0" is rendered as JsonInt 86.
        match decodeOne("12;1;3;2:41.963;0;;41.805;0;1:03.483;0;56.675;0;86.0;6:10.938;11:06:38.429;0:41.805;1:03.483;0:56.675;88.5;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;41.805;63.483;56.675;") {
            case Ok(r) =>
                let json = Json.render(RawLap.toJson(r));
                Assert.assertTrue(String.contains({substr = "\"kph\": 86,"}, json));
                Assert.assertTrue(not String.contains({substr = "\"kph\": 86.0"}, json))
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testToJsonRendersDecimalKphAsFloat(): Unit \ Assert =
        // KPH "107.1" is rendered as JsonFloat 107.1.
        match decodeOne("12;1;3;2:41.963;0;;41.805;0;1:03.483;0;56.675;0;107.1;6:10.938;11:06:38.429;0:41.805;1:03.483;0:56.675;88.5;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;41.805;63.483;56.675;") {
            case Ok(r) =>
                let json = Json.render(RawLap.toJson(r));
                Assert.assertTrue(String.contains({substr = "\"kph\": 107.1"}, json))
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testFromCsvRowNormalizesPitTime(): Unit \ Assert =
        // PIT_TIME "0:01:41.031" is normalised through Duration.normalize
        // to "1:41.031" by the decoder.
        match decodeOne("12;1;3;2:41.963;0;;41.805;0;1:03.483;0;56.675;0;101.4;6:10.938;11:06:38.429;0:41.805;1:03.483;0:56.675;88.5;Will STEVENS;0:01:41.031;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;41.805;63.483;56.675;") {
            case Ok(r)  => Assert.assertTrue(r#pitTime == "1:41.031")
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testFromCsvRowsAllValid(): Unit \ Assert =
        // Two well-formed lines decode into two records, preserving
        // CSV order and fully populating every field including the
        // `group`/`manufacturer` columns.
        let csv =
            header() + "\n" +
            "12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;0:23.155;0:29.928;0:42.282;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;23.155;29.928;42.282;\n7;1;1;1:35.421;0;;23.277;0;29.848;0;42.296;0;160.5;1:35.421;11:02:02.912;0:23.277;0:29.848;0:42.296;;Kamui KOBAYASHI;;HYPERCAR;H;Toyota Gazoo Racing;Toyota;GF;23.277;29.848;42.296;";
        match Decode.decodeCustom(
            {fieldSeparator = ';'},
            FieldNames.FieldNamesFromFirstRow,
            RawLap.decoder(),
            csv
        ) {
            case Ok(records) =>
                Assert.assertTrue(List.length(records) == 2);
                match List.head(records) {
                    case Some(r) =>
                        Assert.assertTrue(r#car#carNumber == "12");
                        Assert.assertTrue(r#driver#driverNumber == 1);
                        Assert.assertTrue(r#car#group == "H");
                        Assert.assertTrue(r#car#manufacturer == "Porsche")
                    case None => Assert.assertTrue(false)
                }
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testFromCsvRowEmptyTopSpeed(): Unit \ Assert =
        // TOP_SPEED blank — common on non-pit laps. The empty string
        // round-trips to JSON unchanged.
        match decodeOne("12;1;3;2:41.963;0;;41.805;0;1:03.483;0;56.675;0;101.4;6:10.938;11:06:38.429;0:41.805;1:03.483;0:56.675;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;41.805;63.483;56.675;") {
            case Ok(r)  => Assert.assertTrue(r#topSpeed == "")
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testToJsonHandlesUnparseableKphAsString(): Unit \ Assert =
        // KPH that parses as neither Int32 nor Float64 falls back to
        // JsonString "not-a-number".
        match decodeOne("12;1;3;2:41.963;0;;41.805;0;1:03.483;0;56.675;0;not-a-number;6:10.938;11:06:38.429;0:41.805;1:03.483;0:56.675;88.5;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;41.805;63.483;56.675;") {
            case Ok(r) =>
                let json = Json.render(RawLap.toJson(r));
                Assert.assertTrue(String.contains({substr = "\"kph\": \"not-a-number\""}, json))
            case Err(_) => Assert.assertTrue(false)
        }

}
