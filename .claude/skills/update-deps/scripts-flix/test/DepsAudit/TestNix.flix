mod DepsAudit.TestNix {

    use DepsAudit.Nix
    use DepsAudit.JsonUtil

    def jsonOf(s: String): Util.Json.Json =
        Util.Json.parse(s) |> Result.getWithDefault(Util.Json.Json.JNull)

    // 2026-07-19 as epoch seconds, used as "now" for the channel audit.
    def now(): Int64 = 1784438400i64

    /// Regression: the audit only matched `nixpkgs-YY.MM-darwin`, so this
    /// repository's `nixos-YY.MM` flake always reported `channel: unknown`.
    @Test
    def testChannelParsesNixosSpelling(): Unit \ Assert =
        let flake = "nixpkgs.url = \"github:nixos/nixpkgs/nixos-26.05\";";
        let out = Nix.renderChannelAudit(flake, now());
        Assert.assertTrue(String.contains({substr = "current channel: nixos-26.05"}, out));
        Assert.assertTrue(not String.contains({substr = "channel: unknown"}, out))

    @Test
    def testChannelParsesNixpkgsDarwinSpelling(): Unit \ Assert =
        let flake = "nixpkgs.url = \"github:nixos/nixpkgs/nixpkgs-25.05-darwin\";";
        let out = Nix.renderChannelAudit(flake, now());
        Assert.assertTrue(String.contains({substr = "current channel: nixpkgs-25.05-darwin"}, out))

    @Test
    def testChannelReportsUpgradeAvailable(): Unit \ Assert =
        let flake = "github:nixos/nixpkgs/nixos-25.05";
        Assert.assertTrue(String.contains({substr = "UPGRADE AVAILABLE"}, Nix.renderChannelAudit(flake, now())))

    @Test
    def testChannelReportsUpToDate(): Unit \ Assert =
        let flake = "github:nixos/nixpkgs/nixos-26.05";
        Assert.assertTrue(String.contains({substr = "up to date"}, Nix.renderChannelAudit(flake, now())))

    @Test
    def testChannelUnknownWhenAbsent(): Unit \ Assert =
        Assert.assertTrue(Nix.renderChannelAudit("nixpkgs.url = \"github:nixos/nixpkgs\";", now()) == "channel: unknown")

    /// The reported latest channel keeps the spelling the flake uses.
    @Test
    def testChannelLabelMatchesInputSpelling(): Unit \ Assert =
        let out = Nix.renderChannelAudit("github:nixos/nixpkgs/nixos-25.05", now());
        Assert.assertTrue(String.contains({substr = "latest channel:  nixos-"}, out))

    // --- flake.lock ---

    @Test
    def testFlakelockRendersPins(): Unit \ Assert =
        let lock = "{\"nodes\":{\"nixpkgs\":{\"locked\":{\"lastModified\":1784217600,\"rev\":\"4382ed2b7a6839d4280a9b386db49cbc5907414d\"}}}}";
        let out = Nix.renderFlakelockAudit(jsonOf(lock));
        Assert.assertTrue(String.contains({substr = "nixpkgs: pinned "}, out));
        // rev is truncated to 12 characters
        Assert.assertTrue(String.contains({substr = "(rev 4382ed2b7a68)"}, out))

    @Test
    def testFlakelockSkipsNodesWithoutLocked(): Unit \ Assert =
        Assert.assertTrue(Nix.renderFlakelockAudit(jsonOf("{\"nodes\":{\"root\":{\"inputs\":{}}}}")) == "")

    /// The parse step is lifted into Main; the label survives via parseDoc.
    @Test
    def testFlakelockParseDocRejectsInvalidJson(): Unit \ Assert =
        match JsonUtil.parseDoc("unexpected flake.lock format", "not json") {
            case Ok(_)  => Assert.assertTrue(false)
            case Err(e) => Assert.assertTrue(String.contains({substr = "unexpected flake.lock format"}, e))
        }

}
