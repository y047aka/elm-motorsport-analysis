mod Cli.TestErrors {

    use Cli.Errors.CliError
    use Util.Files.FileError

    @Test
    def testPathNotFoundRendersPath(): Unit \ Assert =
        let s = "${CliError.InputPathNotFound("/tmp/missing.csv")}";
        Assert.assertTrue(String.contains({substr = "Path not found"}, s));
        Assert.assertTrue(String.contains({substr = "/tmp/missing.csv"}, s))

    @Test
    def testCsvErrorPreservesPathAndCause(): Unit \ Assert =
        let s = "${CliError.Csv({ path = "/tmp/race.csv", message = "Field S1 missing on row 7" })}";
        Assert.assertTrue(String.contains({substr = "/tmp/race.csv"}, s));
        Assert.assertTrue(String.contains({substr = "caused by:"}, s));
        Assert.assertTrue(String.contains({substr = "Field S1 missing on row 7"}, s))

    @Test
    def testFileErrorDelegatesToFileErrorToString(): Unit \ Assert =
        let inner = FileError.ReadError("/tmp/x.csv", "permission denied");
        let s = "${CliError.File(inner)}";
        Assert.assertTrue(s == "Failed to read /tmp/x.csv (caused by: permission denied)")

}
