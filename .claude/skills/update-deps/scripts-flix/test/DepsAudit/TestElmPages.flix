///
/// Tests for the elm-pages compatibilityKey lookup, run against an
/// in-memory `FileIO` handler — no filesystem involved.
///
mod DepsAudit.TestElmPages {

    use DepsAudit.ElmPages
    use DepsAudit.ElmPages.CompatKeyOutcome
    use DepsAudit.Io.FileIO

    /// Run `f` with `FileIO` served from memory: `files` maps a path to
    /// its content, `dirs` maps a directory to its entry names. Writes are
    /// rejected — nothing under test should write.
    def runInMemory(files: Map[String, String], dirs: Map[String, List[String]], f: Unit -> a \ ef): a \ ef - FileIO =
        run { f() } with handler FileIO {
            def read(path, k)     = k(Map.get(path, files) |> Option.toOk("${path}: not found"))
            def write(_, path, k) = k(Err("${path}: read-only test filesystem"))
            def exists(path, k)   = k(Map.memberOf(path, files) or Map.memberOf(path, dirs))
            def list(path, k)     = k(Map.get(path, dirs) |> Option.toOk("${path}: not found"))
        }

    def npmKeyFile(): String =
        "node_modules/elm-pages/src/Pages/Internal/Platform/CompatibilityKey.elm"

    def cacheDir(): String =
        "/home/tester/.elm/0.19.1/packages/dillonkearns/elm-pages"

    def cachedKeyFile(version: String): String =
        "${cacheDir()}/${version}/src/Pages/Internal/Platform/CompatibilityKey.elm"

    def keySource(key: Int64): String =
        "currentCompatibilityKey =\n    ${key}\n"

    @Test
    def testBundledMajor(): Unit \ Assert =
        Assert.assertTrue(ElmPages.bundledMajorFromPackageJson("{\"version\":\"7.3.1\"}") == "7");
        Assert.assertTrue(ElmPages.bundledMajorFromPackageJson("not json") == "unknown")

    @Test
    def testBundledViteMajorReadsNestedPackageJson(): Unit \ Assert =
        let files = Map#{
            "node_modules/elm-pages/node_modules/vite/package.json" => "{\"version\":\"6.2.0\"}",
            "node_modules/vite/package.json" => "{\"version\":\"7.3.1\"}"
        };
        let major = runInMemory(files, Map.empty(), () -> ElmPages.bundledViteMajor());
        Assert.assertEq(expected = "6", major)

    @Test
    def testKeyFileNotFound(): Unit \ Assert =
        let outcome = runInMemory(Map.empty(), Map.empty(), () ->
            ElmPages.resolveCompatKeyAt(Some("/repo"), Some("/home/tester")));
        Assert.assertEq(expected = CompatKeyOutcome.KeyFileNotFound("/repo/${npmKeyFile()}"), outcome)

    @Test
    def testKeyParseFailed(): Unit \ Assert =
        let files = Map#{npmKeyFile() => "module CompatibilityKey exposing (..)"};
        let outcome = runInMemory(files, Map.empty(), () ->
            ElmPages.resolveCompatKeyAt(Some("/repo"), Some("/home/tester")));
        Assert.assertEq(expected = CompatKeyOutcome.KeyParseFailed, outcome)

    @Test
    def testHomeNotSet(): Unit \ Assert =
        let files = Map#{npmKeyFile() => keySource(42i64)};
        let outcome = runInMemory(files, Map.empty(), () ->
            ElmPages.resolveCompatKeyAt(Some("/repo"), None));
        Assert.assertEq(expected = CompatKeyOutcome.HomeNotSet(42i64), outcome)

    @Test
    def testNoMatchingVersion(): Unit \ Assert =
        let files = Map#{
            npmKeyFile()             => keySource(42i64),
            cachedKeyFile("10.0.1")  => keySource(41i64)
        };
        let dirs = Map#{cacheDir() => "10.0.1" :: Nil};
        let outcome = runInMemory(files, dirs, () ->
            ElmPages.resolveCompatKeyAt(Some("/repo"), Some("/home/tester")));
        Assert.assertEq(expected = CompatKeyOutcome.NoMatchingVersion(42i64), outcome)

    @Test
    def testMatchFoundPicksHighestVersion(): Unit \ Assert =
        let files = Map#{
            npmKeyFile()             => keySource(42i64),
            cachedKeyFile("9.0.0")   => keySource(42i64),
            cachedKeyFile("10.1.0")  => keySource(42i64),
            cachedKeyFile("10.0.1")  => keySource(41i64)
        };
        let dirs = Map#{cacheDir() => "9.0.0" :: "10.1.0" :: "10.0.1" :: Nil};
        let outcome = runInMemory(files, dirs, () ->
            ElmPages.resolveCompatKeyAt(Some("/repo"), Some("/home/tester")));
        Assert.assertEq(expected = CompatKeyOutcome.MatchFound(42i64, "10.1.0"), outcome)

}
