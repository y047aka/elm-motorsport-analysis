mod DepsAudit.TestRust {

    use DepsAudit.RustAudit
    use DepsAudit.RustMajor

    // --- rust-minor-audit ---

    @Test
    def testMinorAuditClassifies(): Unit \ Assert =
        let input = "    Updating env_logger v0.11.10 -> v0.11.11\n    Updating memchr v2.8.0 -> v2.8.3\n";
        let out = RustAudit.renderMinorAudit(input);
        Assert.assertTrue(String.contains({substr = "env_logger: 0.11.10 -> 0.11.11"}, out));
        Assert.assertTrue(String.contains({substr = "memchr: 2.8.0 -> 2.8.3"}, out));
        Assert.assertTrue(String.contains({substr = "minor: 1, patch: 1"}, out))

    @Test
    def testMinorAuditAcceptsLockingLines(): Unit \ Assert =
        let out = RustAudit.renderMinorAudit("    Locking jiff v0.2.23 -> v0.2.32");
        Assert.assertTrue(String.contains({substr = "jiff: 0.2.23 -> 0.2.32"}, out))

    @Test
    def testMinorAuditIgnoresNoise(): Unit \ Assert =
        let out = RustAudit.renderMinorAudit("    Updating crates.io index\nnote: pass --verbose");
        Assert.assertTrue(String.contains({substr = "minor: 0, patch: 0"}, out))

    @Test
    def testMinorAuditEmptyInput(): Unit \ Assert =
        let out = RustAudit.renderMinorAudit("");
        Assert.assertTrue(String.contains({substr = "minor: 0, patch: 0"}, out))

    // --- rust-major-audit: Cargo.toml parsing ---

    @Test
    def testParseDepsSimpleAndTable(): Unit \ Assert =
        let toml = "[dependencies]\ncsv = \"1.3\"\nserde = { version = \"1.0\", features = [\"derive\"] }\n";
        let deps = RustMajor.parseDeps(toml :: Nil);
        Assert.assertTrue(List.memberOf(("csv", "1.3"), deps));
        Assert.assertTrue(List.memberOf(("serde", "1.0"), deps))

    @Test
    def testParseDepsStopsAtOtherSection(): Unit \ Assert =
        let toml = "[dependencies]\ncsv = \"1.3\"\n\n[package]\nname = \"cli\"\n";
        let deps = RustMajor.parseDeps(toml :: Nil);
        Assert.assertTrue(List.memberOf(("csv", "1.3"), deps));
        Assert.assertTrue(not List.exists(match (n, _) -> n == "name", deps))

    @Test
    def testParseDepsFirstOccurrenceWins(): Unit \ Assert =
        let a = "[dependencies]\nserde = \"1.0\"\n";
        let b = "[dependencies]\nserde = \"2.0\"\n";
        Assert.assertTrue(List.memberOf(("serde", "1.0"), RustMajor.parseDeps(a :: b :: Nil)))

    @Test
    def testParseDepsWorkspaceAndDevSections(): Unit \ Assert =
        let toml = "[workspace.dependencies]\nserde = \"1.0\"\n\n[dev-dependencies]\ntempfile = \"3.0\"\n";
        let deps = RustMajor.parseDeps(toml :: Nil);
        Assert.assertTrue(List.memberOf(("serde", "1.0"), deps));
        Assert.assertTrue(List.memberOf(("tempfile", "3.0"), deps))

    // --- rust-major-audit: cargo search parsing ---

    @Test
    def testParseSearchOutput(): Unit \ Assert =
        let out = "serde = \"1.0.228\"    # A generic serialization framework";
        Assert.assertTrue(RustMajor.parseSearchOutput("serde", out) == Some("1.0.228"))

    /// Hyphens and underscores are equivalent in crate names.
    @Test
    def testParseSearchOutputNormalizesSeparator(): Unit \ Assert =
        Assert.assertTrue(RustMajor.parseSearchOutput("elm-json", "elm_json = \"0.2.13\"    # desc") == Some("0.2.13"))

    /// A different crate whose name merely starts with the query must not match.
    @Test
    def testParseSearchOutputRejectsPrefixMatch(): Unit \ Assert =
        Assert.assertTrue(RustMajor.parseSearchOutput("serde", "serde_json = \"1.0.150\"    # desc") == None)

    /// A quoted word in the description must not be mistaken for the
    /// version — which is what a greedy regex taking the last quoted run
    /// on the line would do.
    @Test
    def testParseSearchOutputIgnoresQuotesInDescription(): Unit \ Assert =
        let out = "serde = \"1.0.228\"    # A \"generic\" framework";
        Assert.assertTrue(RustMajor.parseSearchOutput("serde", out) == Some("1.0.228"))

    // --- rust-major-audit: report ---

    @Test
    def testMajorAuditSplitsSections(): Unit \ Assert =
        let resolved =
            ("thiserror", "1", Some("2.0.18")) ::
            ("csv", "1.3", Some("1.4.0")) ::
            ("walkdir", "2", None) :: Nil;
        let out = RustMajor.renderMajorAudit(resolved);
        Assert.assertTrue(String.contains({substr = "thiserror: 1 -> 2.0.18"}, out));
        Assert.assertTrue(String.contains({substr = "csv: 1.3 (latest 1.4.0)"}, out));
        Assert.assertTrue(String.contains({substr = "walkdir: 2 (latest unknown)"}, out))

    @Test
    def testMajorAuditNoneWhenEmpty(): Unit \ Assert =
        let out = RustMajor.renderMajorAudit(Nil);
        Assert.assertTrue(String.contains({substr = "--- major updates ---\nnone"}, out))

}
