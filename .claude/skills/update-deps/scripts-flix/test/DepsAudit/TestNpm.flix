mod DepsAudit.TestNpm {

    use DepsAudit.Npm
    use Util.Json.Json

    def lock(): Json =
        Util.Json.parse("{\"packages\":{\"node_modules/vite\":{\"version\":\"7.3.2\"},\"app/node_modules/daisyui\":{\"version\":\"5.6.18\"}}}")
            |> Result.getWithDefault(Util.Json.Json.JNull)

    def jsonOf(s: String): Json =
        Util.Json.parse(s) |> Result.getWithDefault(Util.Json.Json.JNull)

    def pin(raw: String): Result[String, String] =
        Npm.pinFile("package.json", raw, jsonOf(raw), lock(), "")

    // --- npm-pin-versions: only dependencies/devDependencies ---

    @Test
    def testPinRewritesDevDependencies(): Unit \ Assert =
        let raw = "{\n  \"devDependencies\": {\n    \"vite\": \"^7.3.0\"\n  }\n}";
        match pin(raw) {
            case Ok(out) => Assert.assertTrue(String.contains({substr = "\"vite\": \"7.3.2\""}, out))
            case Err(_)  => Assert.assertTrue(false)
        }

    /// Regression: a global text replace also rewrote sibling sections,
    /// pinning peer ranges to exact versions.
    @Test
    def testPinLeavesPeerDependenciesAlone(): Unit \ Assert =
        let raw = "{\n  \"devDependencies\": {\n    \"vite\": \"^7.3.0\"\n  },\n  \"peerDependencies\": {\n    \"vite\": \"^7.3.0\"\n  }\n}";
        match pin(raw) {
            case Ok(out) =>
                // devDependencies pinned, peerDependencies untouched.
                Assert.assertTrue(String.contains({substr = "\"vite\": \"7.3.2\""}, out));
                Assert.assertTrue(String.contains({substr = "\"vite\": \"^7.3.0\""}, out))
            case Err(_) => Assert.assertTrue(false)
        }

    /// Regression: compact JSON silently produced no rewrite and exit 0.
    @Test
    def testPinHandlesCompactJson(): Unit \ Assert =
        match pin("{\"devDependencies\":{\"vite\":\"^7.3.0\"}}") {
            case Ok(out) => Assert.assertTrue(String.contains({substr = "\"vite\":\"7.3.2\""}, out))
            case Err(_)  => Assert.assertTrue(false)
        }

    @Test
    def testPinHandlesExtraWhitespace(): Unit \ Assert =
        match pin("{\"devDependencies\":{\"vite\"   :   \"^7.3.0\"}}") {
            case Ok(out) => Assert.assertTrue(String.contains({substr = "\"7.3.2\""}, out))
            case Err(_)  => Assert.assertTrue(false)
        }

    /// A package absent from the lock falls back to the stripped constraint.
    @Test
    def testPinFallsBackToStrippedConstraint(): Unit \ Assert =
        match pin("{\"dependencies\":{\"leftpad\":\"^1.2.3\"}}") {
            case Ok(out) => Assert.assertTrue(String.contains({substr = "\"leftpad\":\"1.2.3\""}, out))
            case Err(_)  => Assert.assertTrue(false)
        }

    /// A file without the section is returned untouched — no `null` key
    /// is injected (the Rust version did that).
    @Test
    def testPinLeavesMissingSectionAlone(): Unit \ Assert =
        let raw = "{\"name\":\"root\"}";
        match pin(raw) {
            case Ok(out) => Assert.assertTrue(out == raw)
            case Err(_)  => Assert.assertTrue(false)
        }

    @Test
    def testPinWorkspacePrefixWins(): Unit \ Assert =
        let raw = "{\"devDependencies\":{\"daisyui\":\"~5.6.0\"}}";
        match Npm.pinFile("app/package.json", raw, jsonOf(raw), lock(), "app") {
            case Ok(out) => Assert.assertTrue(String.contains({substr = "\"5.6.18\""}, out))
            case Err(_)  => Assert.assertTrue(false)
        }

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
