mod DepsAudit.TestElm {

    use DepsAudit.Elm
    use DepsAudit.JsonUtil

    def jsonOf(s: String): Util.Json.Json =
        Util.Json.parse(s) |> Result.getWithDefault(Util.Json.Json.JNull)

    def appElmJson(): String =
        "{\"type\":\"application\"," +
        "\"dependencies\":{\"direct\":{\"elm/core\":\"1.0.5\"},\"indirect\":{}}," +
        "\"test-dependencies\":{\"direct\":{\"elm-explorations/test\":\"2.2.1\"},\"indirect\":{}}}"

    // --- elm-versions-report ---

    @Test
    def testVersionsReportApplication(): Unit \ Assert =
        let out = Elm.renderVersionsReport("app/elm.json", jsonOf(appElmJson()));
        Assert.assertTrue(String.contains({substr = "--- app/elm.json (application) ---"}, out));
        Assert.assertTrue(String.contains({substr = "direct:"}, out));
        Assert.assertTrue(String.contains({substr = "  elm/core: 1.0.5"}, out));
        Assert.assertTrue(String.contains({substr = "test-direct:"}, out))

    /// The test sections are omitted entirely when both are empty.
    @Test
    def testVersionsReportOmitsEmptyTestSections(): Unit \ Assert =
        let json = "{\"type\":\"application\",\"dependencies\":{\"direct\":{\"elm/core\":\"1.0.5\"},\"indirect\":{}},\"test-dependencies\":{\"direct\":{},\"indirect\":{}}}";
        Assert.assertTrue(not String.contains({substr = "test-direct:"}, Elm.renderVersionsReport("app/elm.json", jsonOf(json))))

    @Test
    def testVersionsReportPackage(): Unit \ Assert =
        let json = "{\"type\":\"package\",\"dependencies\":{\"elm/core\":\"1.0.5 <= v < 2.0.0\"},\"test-dependencies\":{}}";
        let out = Elm.renderVersionsReport("package/elm.json", jsonOf(json));
        Assert.assertTrue(String.contains({substr = "(package)"}, out));
        Assert.assertTrue(String.contains({substr = "dependencies:"}, out));
        Assert.assertTrue(not String.contains({substr = "test-dependencies:"}, out))

    /// The parse step is lifted into Main; the path label survives via parseDoc.
    @Test
    def testParseDocLabelsInvalidJsonWithPath(): Unit \ Assert =
        match JsonUtil.parseDoc("app/elm.json", "not json") {
            case Ok(_)  => Assert.assertTrue(false)
            case Err(e) => Assert.assertTrue(String.contains({substr = "app/elm.json"}, e))
        }

}
