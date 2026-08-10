mod DepsAudit.TestNpm {

    use DepsAudit.Npm
    use Util.Json.Json

    def jsonOf(s: String): Json =
        Util.Json.parse(s) |> Result.getWithDefault(Util.Json.Json.JNull)

    // --- npm-outdated-audit ---

    @Test
    def testOutdatedClassifiesMinorAndMajor(): Unit \ Assert =
        let json = "{\"vite\":{\"current\":\"7.3.2\",\"wanted\":\"7.3.2\",\"latest\":\"8.1.5\"}}";
        match Npm.renderOutdatedAudit(jsonOf(json)) {
            case Ok(report) =>
                Assert.assertTrue(String.contains({substr = "vite: 7.3.2 -> 8.1.5"}, report))
            case Err(_) => Assert.assertTrue(false)
        }

    /// Regression: entries missing required fields were silently dropped
    /// from the report instead of failing.
    @Test
    def testOutdatedRejectsMalformedEntry(): Unit \ Assert =
        match Npm.renderOutdatedAudit(jsonOf("{\"vite\":{\"current\":\"7.3.2\"}}")) {
            case Ok(_)  => Assert.assertTrue(false)
            case Err(e) => Assert.assertTrue(String.contains({substr = "vite"}, e))
        }

    /// Regression: modern pnpm reports `dependentPackages`, so the
    /// dependent column used to always render as `()`.
    @Test
    def testOutdatedReadsDependentPackages(): Unit \ Assert =
        let json = "{\"vite\":{\"current\":\"7.3.2\",\"wanted\":\"7.3.2\",\"latest\":\"8.1.5\",\"dependentPackages\":[{\"name\":\"app\"}]}}";
        match Npm.renderOutdatedAudit(jsonOf(json)) {
            case Ok(report) => Assert.assertTrue(String.contains({substr = "(app)"}, report))
            case Err(_)      => Assert.assertTrue(false)
        }

    // --- npm-security-audit ---

    @Test
    def testSecurityCountsFixKinds(): Unit \ Assert =
        let json = "{\"vulnerabilities\":{\"a\":{\"severity\":\"high\",\"via\":[\"x\"],\"fixAvailable\":true},\"b\":{\"severity\":\"low\",\"via\":[],\"fixAvailable\":{\"name\":\"v\",\"version\":\"2.0.0\",\"isSemVerMajor\":true}}}}";
        let out = Npm.renderSecurityAudit(jsonOf(json));
        Assert.assertTrue(String.contains({substr = "total: 2"}, out));
        Assert.assertTrue(String.contains({substr = "fixable: 1"}, out));
        Assert.assertTrue(String.contains({substr = "fixable-breaking: 1"}, out));
        Assert.assertTrue(String.contains({substr = "(BREAKING)"}, out))

    @Test
    def testSecurityEmptyReport(): Unit \ Assert =
        let out = Npm.renderSecurityAudit(jsonOf("{\"vulnerabilities\":{}}"));
        Assert.assertTrue(String.contains({substr = "total: 0"}, out))

}
