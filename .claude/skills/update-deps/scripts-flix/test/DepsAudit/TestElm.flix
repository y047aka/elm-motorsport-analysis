mod DepsAudit.TestElm {

    use DepsAudit.Elm
    use DepsAudit.ElmPages

    def appElmJson(): String =
        "{\"type\":\"application\"," +
        "\"dependencies\":{\"direct\":{\"elm/core\":\"1.0.5\",\"dillonkearns/elm-pages\":\"12.3.0\"}," +
        "\"indirect\":{\"dillonkearns/elm-ts-json\":\"2.1.3\"}}," +
        "\"test-dependencies\":{\"direct\":{\"elm-explorations/test\":\"2.2.1\"},\"indirect\":{}}}"

    // --- elm-versions-report ---

    @Test
    def testVersionsReportApplication(): Unit \ Assert =
        match Elm.renderVersionsReport("app/elm.json", appElmJson()) {
            case Ok(out) =>
                Assert.assertTrue(String.contains({substr = "--- app/elm.json (application) ---"}, out));
                Assert.assertTrue(String.contains({substr = "direct:"}, out));
                Assert.assertTrue(String.contains({substr = "  elm/core: 1.0.5"}, out));
                Assert.assertTrue(String.contains({substr = "test-direct:"}, out))
            case Err(_) => Assert.assertTrue(false)
        }

    /// The test sections are omitted entirely when both are empty.
    @Test
    def testVersionsReportOmitsEmptyTestSections(): Unit \ Assert =
        let json = "{\"type\":\"application\",\"dependencies\":{\"direct\":{\"elm/core\":\"1.0.5\"},\"indirect\":{}},\"test-dependencies\":{\"direct\":{},\"indirect\":{}}}";
        match Elm.renderVersionsReport("app/elm.json", json) {
            case Ok(out) => Assert.assertTrue(not String.contains({substr = "test-direct:"}, out))
            case Err(_)  => Assert.assertTrue(false)
        }

    @Test
    def testVersionsReportPackage(): Unit \ Assert =
        let json = "{\"type\":\"package\",\"dependencies\":{\"elm/core\":\"1.0.5 <= v < 2.0.0\"},\"test-dependencies\":{}}";
        match Elm.renderVersionsReport("package/elm.json", json) {
            case Ok(out) =>
                Assert.assertTrue(String.contains({substr = "(package)"}, out));
                Assert.assertTrue(String.contains({substr = "dependencies:"}, out));
                Assert.assertTrue(not String.contains({substr = "test-dependencies:"}, out))
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testVersionsReportRejectsInvalidJson(): Unit \ Assert =
        match Elm.renderVersionsReport("app/elm.json", "not json") {
            case Ok(_)  => Assert.assertTrue(false)
            case Err(e) => Assert.assertTrue(String.contains({substr = "app/elm.json"}, e))
        }

    // --- elm-pages-elm-guard ---

    @Test
    def testElmGuardListsDillonkearnsAndRestoreCommands(): Unit \ Assert =
        match ElmPages.renderElmGuard(appElmJson()) {
            case Ok(out) =>
                Assert.assertTrue(String.contains({substr = "dillonkearns/elm-pages: 12.3.0 (direct)"}, out));
                Assert.assertTrue(String.contains({substr = "dillonkearns/elm-ts-json: 2.1.3 (indirect)"}, out));
                // restore commands cover direct packages only
                Assert.assertTrue(String.contains({substr = "elm-json install --yes 'dillonkearns/elm-pages@12.3.0' -- app/elm.json"}, out));
                Assert.assertTrue(not String.contains({substr = "elm-ts-json@2.1.3"}, out));
                // non-dillonkearns packages are not listed
                Assert.assertTrue(not String.contains({substr = "elm/core"}, out))
            case Err(_) => Assert.assertTrue(false)
        }

    // --- elm-pages compatibilityKey / vite ---

    @Test
    def testParseCompatKey(): Unit \ Assert =
        let src = "module Pages.Internal.Platform.CompatibilityKey exposing (currentCompatibilityKey)\n\n\ncurrentCompatibilityKey : Int\ncurrentCompatibilityKey =\n    29\n";
        Assert.assertTrue(ElmPages.parseCompatKey(src) == Some(29i64))

    @Test
    def testParseCompatKeyMissing(): Unit \ Assert =
        Assert.assertTrue(ElmPages.parseCompatKey("module Foo exposing (bar)") == None)

    @Test
    def testViteVersion(): Unit \ Assert =
        match ElmPages.renderViteVersion("vite/package.json", "{\"version\":\"7.3.1\"}") {
            case Ok(v)  => Assert.assertTrue(v == "7.3.1")
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testViteVersionMissingField(): Unit \ Assert =
        match ElmPages.renderViteVersion("vite/package.json", "{}") {
            case Ok(_)  => Assert.assertTrue(false)
            case Err(e) => Assert.assertTrue(String.contains({substr = "missing version"}, e))
        }

    /// The nested (elm-pages-bundled) copy is preferred over the hoisted one.
    @Test
    def testViteCandidateOrder(): Unit \ Assert =
        match ElmPages.vitePackageJsonCandidates() {
            case first :: _ => Assert.assertTrue(String.contains({substr = "elm-pages/node_modules/vite"}, first))
            case Nil        => Assert.assertTrue(false)
        }

    // --- elm-pages-audit version section ---

    @Test
    def testAuditVersionSectionUpToDate(): Unit \ Assert =
        match ElmPages.renderAuditVersionSection("{\"devDependencies\":{\"elm-pages\":\"3.5.1\"}}", Some("3.5.1")) {
            case Ok(out) =>
                Assert.assertTrue(String.contains({substr = "current: 3.5.1"}, out));
                Assert.assertTrue(String.contains({substr = "status:  up to date"}, out))
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testAuditVersionSectionUpdateAvailable(): Unit \ Assert =
        match ElmPages.renderAuditVersionSection("{\"devDependencies\":{\"elm-pages\":\"3.3.4\"}}", Some("3.5.1")) {
            case Ok(out) => Assert.assertTrue(String.contains({substr = "status:  update available"}, out))
            case Err(_)  => Assert.assertTrue(false)
        }

    @Test
    def testAuditVersionSectionUnknownLatest(): Unit \ Assert =
        match ElmPages.renderAuditVersionSection("{\"devDependencies\":{\"elm-pages\":\"3.5.1\"}}", None) {
            case Ok(out) => Assert.assertTrue(String.contains({substr = "latest:  unknown (npm view failed)"}, out))
            case Err(_)  => Assert.assertTrue(false)
        }

    // --- CompatKeyOutcome rendering ---
    //
    // resolveCompatKey() itself needs the filesystem and $HOME, so it isn't
    // unit-tested here; these tests cover the two pure renderers against
    // every outcome directly, without touching disk. Before this, the
    // standalone-vs-audit difference (hard failure vs. graceful degrade)
    // was only reachable by running the actual subcommand.

    @Test
    def testCompatKeyStandaloneFileNotFound(): Unit \ Assert =
        let out = ElmPages.renderCompatKeyStandalone(ElmPages.CompatKeyOutcome.KeyFileNotFound("/repo/node_modules/elm-pages/.../CompatibilityKey.elm"));
        Assert.assertTrue(out#exitCode == 1);
        Assert.assertTrue(List.isEmpty(out#stdout));
        Assert.assertTrue(String.contains({substr = "not found"}, List.head(out#stderr) |> Option.getWithDefault("")))

    @Test
    def testCompatKeyForAuditFileNotFound(): Unit \ Assert =
        let out = ElmPages.renderCompatKeyForAudit(ElmPages.CompatKeyOutcome.KeyFileNotFound("irrelevant/here"));
        Assert.assertTrue(out#exitCode == 0);
        Assert.assertTrue(List.isEmpty(out#stderr));
        Assert.assertTrue(String.contains({substr = "npmKey: unknown (file not found"}, List.head(out#stdout) |> Option.getWithDefault("")))

    @Test
    def testCompatKeyStandaloneParseFailed(): Unit \ Assert =
        let out = ElmPages.renderCompatKeyStandalone(ElmPages.CompatKeyOutcome.KeyParseFailed);
        Assert.assertTrue(out#exitCode == 1);
        Assert.assertTrue(List.exists(l -> String.contains({substr = "could not parse"}, l), out#stderr))

    @Test
    def testCompatKeyForAuditParseFailed(): Unit \ Assert =
        let out = ElmPages.renderCompatKeyForAudit(ElmPages.CompatKeyOutcome.KeyParseFailed);
        Assert.assertTrue(out#exitCode == 0);
        Assert.assertTrue(List.exists(l -> String.contains({substr = "unknown (could not parse)"}, l), out#stdout))

    @Test
    def testCompatKeyStandaloneHomeNotSet(): Unit \ Assert =
        let out = ElmPages.renderCompatKeyStandalone(ElmPages.CompatKeyOutcome.HomeNotSet(29i64));
        Assert.assertTrue(out#exitCode == 1);
        Assert.assertTrue(List.memberOf("npmKey: 29", out#stdout));
        Assert.assertTrue(List.memberOf("HOME not set", out#stderr))

    @Test
    def testCompatKeyForAuditHomeNotSet(): Unit \ Assert =
        let out = ElmPages.renderCompatKeyForAudit(ElmPages.CompatKeyOutcome.HomeNotSet(29i64));
        Assert.assertTrue(out#exitCode == 0);
        Assert.assertTrue(List.isEmpty(out#stderr));
        Assert.assertTrue(List.exists(l -> String.contains({substr = "unknown (HOME not set)"}, l), out#stdout))

    /// NoMatchingVersion and MatchFound render identically in both modes.
    @Test
    def testCompatKeyNoMatchIsGracefulInBothModes(): Unit \ Assert =
        let standalone = ElmPages.renderCompatKeyStandalone(ElmPages.CompatKeyOutcome.NoMatchingVersion(29i64));
        let audit = ElmPages.renderCompatKeyForAudit(ElmPages.CompatKeyOutcome.NoMatchingVersion(29i64));
        Assert.assertTrue(standalone#exitCode == 0);
        Assert.assertTrue(audit#exitCode == 0);
        Assert.assertTrue(standalone#stdout == audit#stdout);
        Assert.assertTrue(List.exists(l -> String.contains({substr = "no-match"}, l), standalone#stdout))

    @Test
    def testCompatKeyMatchFoundIsIdenticalInBothModes(): Unit \ Assert =
        let standalone = ElmPages.renderCompatKeyStandalone(ElmPages.CompatKeyOutcome.MatchFound(29i64, "12.3.0"));
        let audit = ElmPages.renderCompatKeyForAudit(ElmPages.CompatKeyOutcome.MatchFound(29i64, "12.3.0"));
        Assert.assertTrue(standalone#stdout == audit#stdout);
        Assert.assertTrue(standalone#stderr == audit#stderr);
        Assert.assertTrue(standalone#exitCode == audit#exitCode);
        Assert.assertTrue(standalone#exitCode == 0);
        Assert.assertTrue(List.memberOf("npmKey: 29", standalone#stdout));
        Assert.assertTrue(List.memberOf("matchingElmVersion: 12.3.0", standalone#stdout))

}
