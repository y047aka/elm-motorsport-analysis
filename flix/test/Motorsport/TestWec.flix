mod Motorsport.TestWec {

    use Util.Csv.Decode
    use Util.Csv.Decode.{FieldNames, Error}
    use Util.Duration
    use Util.HourClock.Hour
    use Util.Json
    use Motorsport.MiniSector
    use Motorsport.MiniSector.MiniSectorId
    use Motorsport.Wec

    def header(): String =
        "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS"

    /// Le Mans header: base columns + 30 mini-sector columns
    /// (`<NAME>_time;<NAME>_elapsed` for each of the 15 markers in track order).
    def leMansHeader(): String =
        header() +
        ";SCL2_time;SCL2_elapsed;Z4_time;Z4_elapsed;IP1_time;IP1_elapsed" +
        ";Z12_time;Z12_elapsed;SCLC_time;SCLC_elapsed;A7-1_time;A7-1_elapsed;IP2_time;IP2_elapsed" +
        ";A8-1_time;A8-1_elapsed;SCLB_time;SCLB_elapsed;PORIN_time;PORIN_elapsed;POROUT_time;POROUT_elapsed;PITREF_time;PITREF_elapsed;SCL1_time;SCL1_elapsed;FORDOUT_time;FORDOUT_elapsed;FL_time;FL_elapsed"

    /// Decodes a single semicolon-separated CSV line (without header) and
    /// pulls the first record out of the result. The header row is prepended
    /// automatically so the decoder can resolve field names.
    def decodeOne(line: String): Result[Error, Wec.RawLap] =
        match Decode.decodeCustom(
            {fieldSeparator = ';'},
            FieldNames.FieldNamesFromFirstRow,
            Wec.decoder(),
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
                Assert.assertTrue(r#driver#number == 1);
                Assert.assertTrue(r#lapNumber == 3);
                Assert.assertTrue(r#lapTime == Duration.fromMillis(161963));
                Assert.assertTrue(r#lapImprovement == Wec.Improvement.None);
                Assert.assertTrue(r#crossingFinishLineInPit == false);
                Assert.assertTrue(r#s1#value == Some(Duration.fromMillis(41805)));
                Assert.assertTrue(r#s1#improvement == Wec.Improvement.None);
                Assert.assertTrue(r#s2#value == Some(Duration.fromMillis(63483)));
                Assert.assertTrue(r#s3#value == Some(Duration.fromMillis(56675)));
                Assert.assertTrue(r#kph == "101.4");
                Assert.assertTrue(r#elapsed == Duration.fromMillis(370938));
                Assert.assertTrue(r#hour == Hour.Hour(39998429));
                Assert.assertTrue(r#topSpeed == "88.5");
                Assert.assertTrue(r#driver#name == "Will STEVENS");
                Assert.assertTrue(r#pitTime == None);
                Assert.assertTrue(r#car#class == "HYPERCAR");
                Assert.assertTrue(r#car#group == "H");
                Assert.assertTrue(r#car#team == "Hertz Team JOTA");
                Assert.assertTrue(r#car#manufacturer == "Porsche");
                Assert.assertTrue(r#flagAtFl == Wec.Flag.SlowZone)
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testTopSpeedPreservedAsIs(): Unit \ Assert =
        // TOP_SPEED "150.0" is kept as-is (no .0 stripping).
        match decodeOne("12;1;3;2:41.963;0;;41.805;0;1:03.483;0;56.675;0;101.4;6:10.938;11:06:38.429;0:41.805;1:03.483;0:56.675;150.0;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;41.805;63.483;56.675;") {
            case Ok(r)  => Assert.assertTrue(r#topSpeed == "150.0")
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testToJsonRendersKphAsString(): Unit \ Assert =
        // KPH is rendered as a JSON string, preserving the CSV value.
        match decodeOne("12;1;3;2:41.963;0;;41.805;0;1:03.483;0;56.675;0;86.0;6:10.938;11:06:38.429;0:41.805;1:03.483;0:56.675;88.5;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;41.805;63.483;56.675;") {
            case Ok(r) =>
                let json = Json.render(Wec.toJson(r));
                Assert.assertTrue(String.contains({substr = "\"kph\": \"86.0\""}, json))
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testFromCsvRowNormalizesPitTime(): Unit \ Assert =
        // PIT_TIME "0:01:41.031" is parsed to ms and re-rendered as "1:41.031"
        // by the decoder + JSON encoder pipeline.
        match decodeOne("12;1;3;2:41.963;0;;41.805;0;1:03.483;0;56.675;0;101.4;6:10.938;11:06:38.429;0:41.805;1:03.483;0:56.675;88.5;Will STEVENS;0:01:41.031;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;41.805;63.483;56.675;") {
            case Ok(r)  => Assert.assertTrue(r#pitTime == Some(Duration.fromMillis(101031)))
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testFromCsvRowsAllValid(): Unit \ Assert =
        // Two well-formed rows decode into two records.
        let csv =
            header() + "\n" +
            "12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:02.856;0:23.155;0:29.928;0:42.282;;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;23.155;29.928;42.282;\n7;1;1;1:35.421;0;;23.277;0;29.848;0;42.296;0;160.5;1:35.421;11:02:02.912;0:23.277;0:29.848;0:42.296;;Kamui KOBAYASHI;;HYPERCAR;H;Toyota Gazoo Racing;Toyota;GF;23.277;29.848;42.296;";
        match Decode.decodeCustom(
            {fieldSeparator = ';'},
            FieldNames.FieldNamesFromFirstRow,
            Wec.decoder(),
            csv
        ) {
            case Ok(records) => Assert.assertTrue(List.length(records) == 2)
            case Err(_)      => Assert.assertTrue(false)
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
    def testUnparseableKphFailsDecode(): Unit \ Assert =
        // KPH that parses as neither Int32 nor Float64 fails decode.
        match decodeOne("12;1;3;2:41.963;0;;41.805;0;1:03.483;0;56.675;0;not-a-number;6:10.938;11:06:38.429;0:41.805;1:03.483;0:56.675;88.5;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;41.805;63.483;56.675;") {
            case Ok(_)  => Assert.assertTrue(false)
            case Err(_) => Assert.assertTrue(true)
        }

    @Test
    def testBlankLapTimeFailsDecode(): Unit \ Assert =
        match decodeOne("12;1;3;;0;;41.805;0;1:03.483;0;56.675;0;101.4;6:10.938;11:06:38.429;0:41.805;1:03.483;0:56.675;88.5;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;41.805;63.483;56.675;") {
            case Ok(_)  => Assert.assertTrue(false)
            case Err(_) => Assert.assertTrue(true)
        }

    @Test
    def testUnparseableHourFailsDecode(): Unit \ Assert =
        match decodeOne("12;1;3;2:41.963;0;;41.805;0;1:03.483;0;56.675;0;101.4;6:10.938;garbage;0:41.805;1:03.483;0:56.675;88.5;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;41.805;63.483;56.675;") {
            case Ok(_)  => Assert.assertTrue(false)
            case Err(_) => Assert.assertTrue(true)
        }

    @Test
    def testNonLeMansCsvLeavesMiniSectorsNone(): Unit \ Assert =
        // The standard WEC header has no mini-sector columns, so decode
        // should succeed with `miniSectors == None` and `toJson` must omit
        // the `miniSectors` key entirely.
        match decodeOne("12;1;3;2:41.963;0;;41.805;0;1:03.483;0;56.675;0;101.4;6:10.938;11:06:38.429;0:41.805;1:03.483;0:56.675;88.5;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;41.805;63.483;56.675;") {
            case Ok(r) =>
                let isNone = match r#miniSectors {
                    case None    => true
                    case Some(_) => false
                };
                Assert.assertTrue(isNone);
                let json = Json.render(Wec.toJson(r));
                Assert.assertTrue(not String.contains({substr = "miniSectors"}, json))
            case Err(_) => Assert.assertTrue(false)
        }

    /// Decode a single Le Mans-shaped row (base 29 fields + 30 mini-sector fields).
    def decodeLeMansOne(line: String): Result[Error, Wec.RawLap] =
        match Decode.decodeCustom(
            {fieldSeparator = ';'},
            FieldNames.FieldNamesFromFirstRow,
            Wec.decoder(),
            leMansHeader() + "\n" + line
        ) {
            case Ok(r :: _) => Ok(r)
            case Ok(Nil)    => Err(Error.DecodingErrors(Nil))
            case Err(e)     => Err(e)
        }

    /// Real first-lap row from app/static/wec/2025/le_mans_24h.csv (car 007 lap 1).
    def realLeMansLapRow(): String =
        "007;1;1;3:54.555;0;;51.908;0;1:23.252;0;1:39.395;0;206.9;3:54.555;16:03:54.555;0:51.908;1:23.252;1:39.395;328.8;Harry TINCKNELL;;HYPERCAR;;Aston Martin Thor Team;Aston Martin;GF;51.908;83.252;99.395;" +
        "20.708;20.708;13.826;34.534;17.374;51.908;" +
        "35.154;1:27.062;4.685;1:31.747;26.059;1:57.806;17.354;2:15.160;" +
        "6.928;2:22.088;37.644;2:59.732;17.155;3:16.887;16.786;3:33.673;7.954;3:41.627;2.885;3:44.512;6.560;3:51.072;3.483;3:54.555"

    @Test
    def testLeMansRowDecodesAllFifteenMiniSectors(): Unit \ Assert =
        match decodeLeMansOne(realLeMansLapRow()) {
            case Ok(r) =>
                match r#miniSectors {
                    case None       => Assert.assertTrue(false)
                    case Some(list) =>
                        Assert.assertTrue(List.length(list) == 15);
                        // First entry must be SCL2 with time=20.708 (= 20708 ms).
                        match List.head(list) {
                            case Some((id, sector)) =>
                                Assert.assertTrue(id == MiniSectorId.SCL2);
                                Assert.assertTrue(sector#time == Some(Duration.fromMillis(20708)));
                                Assert.assertTrue(sector#elapsed == Some(Duration.fromMillis(20708)))
                            case None => Assert.assertTrue(false)
                        };
                        // Last entry must be FL with elapsed = lapTime (3:54.555 = 234555 ms).
                        match List.last(list) {
                            case Some((id, sector)) =>
                                Assert.assertTrue(id == MiniSectorId.FL);
                                Assert.assertTrue(sector#elapsed == Some(Duration.fromMillis(234555)))
                            case None => Assert.assertTrue(false)
                        }
                }
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testLeMansRowJsonContainsMiniSectorsWithHyphenedKeys(): Unit \ Assert =
        // Confirm A7-1 / A8-1 round-trip to a7_1 / a8_1 in the JSON output
        // (matches Motorsport.Lap.MiniSectors field names on the Elm side).
        match decodeLeMansOne(realLeMansLapRow()) {
            case Ok(r) =>
                let json = Json.render(Wec.toJson(r));
                Assert.assertTrue(String.contains({substr = "\"miniSectors\""}, json));
                Assert.assertTrue(String.contains({substr = "\"a7_1\""}, json));
                Assert.assertTrue(String.contains({substr = "\"a8_1\""}, json));
                Assert.assertTrue(not String.contains({substr = "\"a7-1\""}, json));
                Assert.assertTrue(String.contains({substr = "\"scl2\""}, json));
                Assert.assertTrue(String.contains({substr = "\"fl\""}, json))
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testLeMansRowAllBlankMiniSectorsCollapseToNone(): Unit \ Assert =
        // When every mini-sector column in a Le Mans row is blank, the
        // whole `miniSectors` field collapses to None and the JSON omits
        // the key.
        let blanks = ";;;;;;;;;;;;;;;;;;;;;;;;;;;;;;";
        let line =
            "007;1;1;3:54.555;0;;51.908;0;1:23.252;0;1:39.395;0;206.9;3:54.555;16:03:54.555;0:51.908;1:23.252;1:39.395;328.8;Harry TINCKNELL;;HYPERCAR;;Aston Martin Thor Team;Aston Martin;GF;51.908;83.252;99.395" +
            blanks;
        match decodeLeMansOne(line) {
            case Ok(r) =>
                let isNone = match r#miniSectors {
                    case None    => true
                    case Some(_) => false
                };
                Assert.assertTrue(isNone);
                let json = Json.render(Wec.toJson(r));
                Assert.assertTrue(not String.contains({substr = "miniSectors"}, json))
            case Err(_) => Assert.assertTrue(false)
        }

}
