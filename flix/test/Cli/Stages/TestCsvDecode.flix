mod Cli.Stages.TestCsvDecode {

    use Cli.Stages.CsvDecode
    use Cli.Errors.CliError

    def header(): String =
        "NUMBER;DRIVER_NUMBER;LAP_NUMBER;LAP_TIME;LAP_IMPROVEMENT;CROSSING_FINISH_LINE_IN_PIT;S1;S1_IMPROVEMENT;S2;S2_IMPROVEMENT;S3;S3_IMPROVEMENT;KPH;ELAPSED;HOUR;S1_LARGE;S2_LARGE;S3_LARGE;TOP_SPEED;DRIVER_NAME;PIT_TIME;CLASS;GROUP;TEAM;MANUFACTURER;FLAG_AT_FL;S1_SECONDS;S2_SECONDS;S3_SECONDS"

    def sampleRow(): String =
        "12;1;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:00.000;;;;310.5;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;;;"

    @Test
    def testDecodeParsesValidCsv(): Unit \ Assert =
        let csv = header() + "\n" + sampleRow();
        match CsvDecode.decode("test.csv", csv) {
            case Ok(laps) => Assert.assertTrue(List.length(laps) == 1)
            case Err(_)   => Assert.assertTrue(false)
        }

    @Test
    def testDecodeStripsBom(): Unit \ Assert =
        let csv = "\u{FEFF}" + header() + "\n" + sampleRow();
        match CsvDecode.decode("test.csv", csv) {
            case Ok(laps) => Assert.assertTrue(List.length(laps) == 1)
            case Err(_)   => Assert.assertTrue(false)
        }

    @Test
    def testDecodeAttachesPathOnError(): Unit \ Assert =
        let broken = header() + "\n" + "12;not-a-number;1;1:35.365;0;;23.155;0;29.928;0;42.282;0;160.7;1:35.365;11:02:00.000;;;;310.5;Will STEVENS;;HYPERCAR;H;Hertz Team JOTA;Porsche;GF;;;";
        match CsvDecode.decode("/tmp/race.csv", broken) {
            case Ok(_) => Assert.assertTrue(false)
            case Err(CliError.Csv(r)) =>
                Assert.assertTrue(r#path == "/tmp/race.csv")
            case Err(_) => Assert.assertTrue(false)
        }

}
