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

    /// An entry missing a required field fails the report rather than being
    /// silently dropped from it.
    @Test
    def testOutdatedRejectsMalformedEntry(): Unit \ Assert =
        match Npm.renderOutdatedAudit(jsonOf("{\"vite\":{\"current\":\"7.3.2\"}}")) {
            case Ok(_)  => Assert.assertTrue(false)
            case Err(e) => Assert.assertTrue(String.contains({substr = "vite"}, e))
        }

    /// `app/` is the only npm project, so the report names no workspace
    /// project: a `dependentPackages` entry must not bring the column back.
    @Test
    def testOutdatedOmitsDependentColumn(): Unit \ Assert =
        let json = "{\"vite\":{\"current\":\"7.3.2\",\"wanted\":\"7.3.2\",\"latest\":\"8.1.5\",\"dependentPackages\":[{\"name\":\"app\"}]}}";
        match Npm.renderOutdatedAudit(jsonOf(json)) {
            case Ok(report) =>
                Assert.assertTrue(String.contains({substr = "vite: 7.3.2 -> 8.1.5"}, report));
                Assert.assertTrue(not String.contains({substr = "("}, report))
            case Err(_) => Assert.assertTrue(false)
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
