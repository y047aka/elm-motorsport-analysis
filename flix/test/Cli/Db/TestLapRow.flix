mod Cli.Db.TestLapRow {

    use Cli.Db.LapRow
    use Cli.Db.LapRow.Value
    use Motorsport.Calendar.Entry
    use Motorsport.Wec
    use Motorsport.Wec.RawLap
    use Util.Csv.Decode
    use Util.Csv.Decode.FieldNames

    def fuji(): Entry = { season = 2025, id = "fuji_6h", date = "2025-09-28" }

    def header(): String =
        "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS"

    def decodeCsv(csv: String): List[RawLap] =
        match Decode.decodeCustom(
            {fieldSeparator = ';'},
            FieldNames.FieldNamesFromFirstRow,
            Wec.decoder(),
            csv
        ) {
            case Ok(rs) => rs
            case Err(_) => unreachable!()
        }

    pub def sampleLap(): RawLap = plainLap()

    def plainLap(): RawLap =
        let csv =
            header() + "\n" +
            "12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;2;160.7;1:35.365;11:02:00.000;;;;310.5;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;SF;;;";
        match decodeCsv(csv) {
            case lap :: _ => lap
            case Nil      => unreachable!()
        }

    def pitLap(): RawLap =
        let csv =
            header() + "\n" +
            "12;2;2;2:41.001;0;B;23.155;0;29.928;0;42.282;0;160.7;4:16.366;11:04:41.001;;;;;Robin FRIJNS;1:05.500;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;;;";
        match decodeCsv(csv) {
            case lap :: _ => lap
            case Nil      => unreachable!()
        }

    def miniSectorLap(): RawLap =
        let csv =
            header() + ";SCL2_time;SCL2_elapsed\n" +
            "7;1;1;1:33.291;0;;23.119;0;29.188;0;40.984;0;175.0;1:33.291;11:02:00.000;;;;298.6;Kamui KOBAYASHI;;HYPERCAR;H;Toyota Gazoo Racing;Toyota;GF;;;;20.708;20.708";
        match decodeCsv(csv) {
            case lap :: _ => lap
            case Nil      => unreachable!()
        }

    @Test
    def theRoundIsTheCalendarEntryAndNotTheFeed(): Unit \ Assert =
        let row = LapRow.fromRawLap(fuji(), 1, plainLap());
        Assert.assertTrue(row#season == 2025);
        Assert.assertTrue(row#round == "fuji_6h")

    @Test
    def durationsBecomeMilliseconds(): Unit \ Assert =
        let row = LapRow.fromRawLap(fuji(), 1, plainLap());
        Assert.assertTrue(row#lapTimeMs == 95365);
        Assert.assertTrue(row#elapsedMs == 95365);
        Assert.assertTrue(row#s1Ms == Some(23155));
        Assert.assertTrue(row#s2Ms == Some(29928));
        Assert.assertTrue(row#s3Ms == Some(42282))

    @Test
    def theHourBecomesMillisecondsSinceMidnight(): Unit \ Assert =
        let row = LapRow.fromRawLap(fuji(), 1, plainLap());
        Assert.assertTrue(row#hourMs == 39720000)

    @Test
    def flagsAndImprovementsKeepTheEncodingTheJsonUses(): Unit \ Assert =
        let row = LapRow.fromRawLap(fuji(), 1, plainLap());
        Assert.assertTrue(row#flagAtFl == "SF");
        Assert.assertTrue(row#lapImprovement == 0);
        Assert.assertTrue(row#s3Improvement == 2)

    @Test
    def speedsStayTheTextTheFeedGave(): Unit \ Assert =
        let row = LapRow.fromRawLap(fuji(), 1, plainLap());
        Assert.assertTrue(row#kph == "160.7");
        Assert.assertTrue(row#topSpeed == "310.5")

    @Test
    def whatTheFeedLeftBlankIsAbsent(): Unit \ Assert =
        let row = LapRow.fromRawLap(fuji(), 1, plainLap());
        Assert.assertTrue(row#pitTimeMs == None);
        Assert.assertTrue(row#miniSectors == None);
        let pit = LapRow.fromRawLap(fuji(), 2, pitLap());
        Assert.assertTrue(pit#pitTimeMs == Some(65500));
        Assert.assertTrue(pit#topSpeed == "")

    @Test
    def theBoxColumnBecomesABoolean(): Unit \ Assert =
        Assert.assertTrue(not LapRow.fromRawLap(fuji(), 1, plainLap())#crossingFinishLineInPit);
        Assert.assertTrue(LapRow.fromRawLap(fuji(), 2, pitLap())#crossingFinishLineInPit)

    /// The object the JSON Lines output carries, on one line: the two readings
    /// of a round cannot disagree about what was measured.
    @Test
    def miniSectorsBecomeTheJsonTheFilesCarry(): Unit \ Assert =
        let row = LapRow.fromRawLap(fuji(), 1, miniSectorLap());
        Assert.assertTrue(row#miniSectors == Some("{ \"scl2\": { \"time\": \"20.708\", \"elapsed\": \"20.708\" } }"))

    @Test
    def everyLapOfTheRoundBecomesARow(): Unit \ Assert =
        let rows = LapRow.fromRawLaps(fuji(), plainLap() :: pitLap() :: Nil);
        Assert.assertTrue(List.length(rows) == 2);
        Assert.assertTrue(List.map(r -> r#lapNumber, rows) == 1 :: 2 :: Nil)

    /// The file's order, not the lap's: the two agree for one car and part
    /// company as soon as a second one is interleaved with it.
    @Test
    def theRowsAreNumberedByWhereTheFileListedThem(): Unit \ Assert =
        let rows = LapRow.fromRawLaps(fuji(), pitLap() :: plainLap() :: pitLap() :: Nil);
        Assert.assertTrue(List.map(r -> r#sourceRow, rows) == 1 :: 2 :: 3 :: Nil);
        Assert.assertTrue(List.map(r -> r#lapNumber, rows) == 2 :: 1 :: 2 :: Nil)

    @Test
    def theRowIsBoundInTheOrderTheColumnsAreNamed(): Unit \ Assert =
        let values = LapRow.values(LapRow.fromRawLap(fuji(), 1, plainLap()));
        Assert.assertTrue(List.take(4, values)
            == Value.Integer(2025) :: Value.Text("fuji_6h") :: Value.Integer(1) :: Value.Text("12") :: Nil);
        Assert.assertTrue(List.last(values) == Some(Value.NullableJsonb(None)))

}
