mod DepsAudit.TestElm {

    use DepsAudit.Cli
    use DepsAudit.Elm
    use DepsAudit.ElmPages
    use DepsAudit.JsonUtil

    def jsonOf(s: String): Util.Json.Json =
        Util.Json.parse(s) |> Result.getWithDefault(Util.Json.Json.JNull)

    def appElmJson(): String =
        "{\"type\":\"application\"," +
        "\"dependencies\":{\"direct\":{\"elm/core\":\"1.0.5\",\"dillonkearns/elm-pages\":\"12.3.0\"}," +
        "\"indirect\":{\"dillonkearns/elm-ts-json\":\"2.1.3\"}}," +
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

    // --- elm-pages-elm-guard ---

    @Test
    def testElmGuardListsDillonkearnsAndRestoreCommands(): Unit \ Assert =
        let out = ElmPages.renderElmGuard(jsonOf(appElmJson()));
        Assert.assertTrue(String.contains({substr = "dillonkearns/elm-pages: 12.3.0 (direct)"}, out));
        Assert.assertTrue(String.contains({substr = "dillonkearns/elm-ts-json: 2.1.3 (indirect)"}, out));
        // restore commands cover direct packages only
        Assert.assertTrue(String.contains({substr = "elm-json install --yes 'dillonkearns/elm-pages@12.3.0' -- app/elm.json"}, out));
        Assert.assertTrue(not String.contains({substr = "elm-ts-json@2.1.3"}, out));
        // non-dillonkearns packages are not listed
        Assert.assertTrue(not String.contains({substr = "elm/core"}, out))

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
        match ElmPages.renderViteVersion(jsonOf("{\"version\":\"7.3.1\"}")) {
            case Ok(v)  => Assert.assertTrue(v == "7.3.1")
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testViteVersionMissingField(): Unit \ Assert =
        match ElmPages.renderViteVersion(jsonOf("{}")) {
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
        let out = ElmPages.renderAuditVersionSection(jsonOf("{\"devDependencies\":{\"elm-pages\":\"3.5.1\"}}"), Some("3.5.1"));
        Assert.assertTrue(String.contains({substr = "current: 3.5.1"}, out));
        Assert.assertTrue(String.contains({substr = "status:  up to date"}, out))

    @Test
    def testAuditVersionSectionUpdateAvailable(): Unit \ Assert =
        let out = ElmPages.renderAuditVersionSection(jsonOf("{\"devDependencies\":{\"elm-pages\":\"3.3.4\"}}"), Some("3.5.1"));
        Assert.assertTrue(String.contains({substr = "status:  update available"}, out))

    @Test
    def testAuditVersionSectionUnknownLatest(): Unit \ Assert =
        let out = ElmPages.renderAuditVersionSection(jsonOf("{\"devDependencies\":{\"elm-pages\":\"3.5.1\"}}"), None);
        Assert.assertTrue(String.contains({substr = "latest:  unknown (npm view failed)"}, out))

    // --- CompatKeyOutcome rendering ---
    //
    // The lookup itself is covered in TestElmPages; these tests cover the
    // two pure renderers (hard failure vs. graceful degrade) against every
    // outcome directly, without touching disk.

    @Test
    def testCompatKeyStandaloneFileNotFound(): Unit \ Assert =
        let out = ElmPages.renderCompatKeyStandalone(ElmPages.CompatKeyOutcome.KeyFileNotFound("/repo/node_modules/elm-pages/.../CompatibilityKey.elm"));
        Assert.assertTrue(Cli.exitCode(out) == 1);
        Assert.assertTrue(List.isEmpty(Cli.stdout(out)));
        Assert.assertTrue(String.contains({substr = "not found"}, List.head(Cli.stderr(out)) |> Option.getWithDefault("")))

    @Test
    def testCompatKeyForAuditFileNotFound(): Unit \ Assert =
        let out = ElmPages.renderCompatKeyForAudit(ElmPages.CompatKeyOutcome.KeyFileNotFound("irrelevant/here"));
        Assert.assertTrue(Cli.exitCode(out) == 0);
        Assert.assertTrue(List.isEmpty(Cli.stderr(out)));
        Assert.assertTrue(String.contains({substr = "npmKey: unknown (file not found"}, List.head(Cli.stdout(out)) |> Option.getWithDefault("")))

    @Test
    def testCompatKeyStandaloneParseFailed(): Unit \ Assert =
        let out = ElmPages.renderCompatKeyStandalone(ElmPages.CompatKeyOutcome.KeyParseFailed);
        Assert.assertTrue(Cli.exitCode(out) == 1);
        Assert.assertTrue(List.exists(l -> String.contains({substr = "could not parse"}, l), Cli.stderr(out)))

    @Test
    def testCompatKeyForAuditParseFailed(): Unit \ Assert =
        let out = ElmPages.renderCompatKeyForAudit(ElmPages.CompatKeyOutcome.KeyParseFailed);
        Assert.assertTrue(Cli.exitCode(out) == 0);
        Assert.assertTrue(List.exists(l -> String.contains({substr = "unknown (could not parse)"}, l), Cli.stdout(out)))

    @Test
    def testCompatKeyStandaloneHomeNotSet(): Unit \ Assert =
        let out = ElmPages.renderCompatKeyStandalone(ElmPages.CompatKeyOutcome.HomeNotSet(29i64));
        Assert.assertTrue(Cli.exitCode(out) == 1);
        Assert.assertTrue(List.memberOf("npmKey: 29", Cli.stdout(out)));
        Assert.assertTrue(List.memberOf("HOME not set", Cli.stderr(out)))

    @Test
    def testCompatKeyForAuditHomeNotSet(): Unit \ Assert =
        let out = ElmPages.renderCompatKeyForAudit(ElmPages.CompatKeyOutcome.HomeNotSet(29i64));
        Assert.assertTrue(Cli.exitCode(out) == 0);
        Assert.assertTrue(List.isEmpty(Cli.stderr(out)));
        Assert.assertTrue(List.exists(l -> String.contains({substr = "unknown (HOME not set)"}, l), Cli.stdout(out)))

    /// A resolved key (match or no-match) renders identically in both modes.
    @Test
    def testCompatKeyNoMatchIsGracefulInBothModes(): Unit \ Assert =
        let standalone = ElmPages.renderCompatKeyStandalone(ElmPages.CompatKeyOutcome.Resolved(29i64, None));
        let audit = ElmPages.renderCompatKeyForAudit(ElmPages.CompatKeyOutcome.Resolved(29i64, None));
        Assert.assertTrue(Cli.exitCode(standalone) == 0);
        Assert.assertTrue(Cli.exitCode(audit) == 0);
        Assert.assertTrue(Cli.stdout(standalone) == Cli.stdout(audit));
        Assert.assertTrue(List.exists(l -> String.contains({substr = "no-match"}, l), Cli.stdout(standalone)))

    @Test
    def testCompatKeyMatchFoundIsIdenticalInBothModes(): Unit \ Assert =
        let standalone = ElmPages.renderCompatKeyStandalone(ElmPages.CompatKeyOutcome.Resolved(29i64, Some("12.3.0")));
        let audit = ElmPages.renderCompatKeyForAudit(ElmPages.CompatKeyOutcome.Resolved(29i64, Some("12.3.0")));
        Assert.assertTrue(Cli.stdout(standalone) == Cli.stdout(audit));
        Assert.assertTrue(Cli.stderr(standalone) == Cli.stderr(audit));
        Assert.assertTrue(Cli.exitCode(standalone) == Cli.exitCode(audit));
        Assert.assertTrue(Cli.exitCode(standalone) == 0);
        Assert.assertTrue(List.memberOf("npmKey: 29", Cli.stdout(standalone)));
        Assert.assertTrue(List.memberOf("matchingElmVersion: 12.3.0", Cli.stdout(standalone)))

}
