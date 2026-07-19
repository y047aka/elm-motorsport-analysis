///
/// nix-channel-audit and nix-flakelock-audit. Port of scripts/src/nix.rs.
///
mod DepsAudit.Nix {

    use Util.Json.Json
    use Util.Json.Json.{JObject, JNumber}
    use DepsAudit.Date
    use DepsAudit.JsonUtil

    /// Which spelling of the channel a flake.nix uses.
    pub enum ChannelStyle with Eq {
        case Nixos          // nixos-YY.MM
        case NixpkgsDarwin  // nixpkgs-YY.MM-darwin
    }

    /// Render the channel report from flake.nix content and the current
    /// epoch time in seconds.
    ///
    /// Both channel spellings are recognised: the plain `nixos-YY.MM` this
    /// repository uses, and the `nixpkgs-YY.MM-darwin` form the Rust version
    /// assumed (it only matched the latter, so the audit reported
    /// `channel: unknown` on every run here).
    pub def renderChannelAudit(flakeContent: String, nowSecs: Int64): String =
        match parseChannel(flakeContent) {
            case Some((style, yy, mm)) =>
                let current = "current channel: ${channelLabel(style, yy, mm)}";
                let (nowYear, nowMonth, _) = Date.daysToYmd(nowSecs / 86400i64);
                let nowYy = nowYear - (nowYear / 100i64) * 100i64;
                match latestStableChannel(nowYy, nowMonth) {
                    case Some((latestYy, latestMm)) =>
                        let currentNum = yy * 100i64 + mm;
                        let latestNum = latestYy * 100i64 + latestMm;
                        let suffix = if (latestNum > currentNum) "  <- UPGRADE AVAILABLE" else "  (up to date)";
                        current + "\n" + "latest channel:  ${channelLabel(style, latestYy, latestMm)}${suffix}"
                    case None =>
                        current + "\n" + "latest channel: unknown"
                }
            case None => "channel: unknown"
        }

    /// Extract the pinned channel, trying both spellings.
    pub def parseChannel(flakeContent: String): Option[(ChannelStyle, Int64, Int64)] =
        let darwinRgx = regex"nixpkgs-(\\d+)\\.(\\d+)-darwin";
        let nixosRgx = regex"nixos-(\\d+)\\.(\\d+)";
        match Regex.capture(darwinRgx, flakeContent) {
            case yyS :: mmS :: Nil => channelFrom(ChannelStyle.NixpkgsDarwin, yyS, mmS)
            case _ => match Regex.capture(nixosRgx, flakeContent) {
                case yyS :: mmS :: Nil => channelFrom(ChannelStyle.Nixos, yyS, mmS)
                case _                 => None
            }
        }

    /// A channel triple from its captured year/month strings.
    def channelFrom(style: ChannelStyle, yyS: String, mmS: String): Option[(ChannelStyle, Int64, Int64)] =
        forM (
            yy <- Int64.fromString(yyS);
            mm <- Int64.fromString(mmS)
        ) yield (style, yy, mm)

    /// Render a channel label in the same spelling the flake uses.
    pub def channelLabel(style: ChannelStyle, yy: Int64, mm: Int64): String =
        match style {
            case ChannelStyle.Nixos         => "nixos-${yy}.${Date.pad2(mm)}"
            case ChannelStyle.NixpkgsDarwin => "nixpkgs-${yy}.${Date.pad2(mm)}-darwin"
        }

    /// Latest stable channel label (May/November releases from 24.05 on).
    def latestStableChannel(nowYy: Int64, nowMonth: Int64): Option[(Int64, Int64)] =
        def loop(y, latest) =
            if (y > nowYy) latest
            else {
                let afterMay = if (y < nowYy or 5i64 <= nowMonth) Some((y, 5i64)) else latest;
                let afterNov = if (y < nowYy or 11i64 <= nowMonth) Some((y, 11i64)) else afterMay;
                loop(y + 1i64, afterNov)
            };
        loop(24i64, None)

    /// Render the flake.lock pin report from the parsed lockfile.
    pub def renderFlakelockAudit(lock: Json): String =
        let nodes = match JsonUtil.getKey("nodes", lock) {
            case Some(JObject(m)) => Map.toList(m)
            case _                => Nil
        };
        nodes
            |> List.filterMap(match (name, node) ->
                JsonUtil.getKey("locked", node) |> Option.map(locked -> pinLine(name, locked)))
            |> List.join("\n")

    /// One "name: pinned YYYY-MM-DD (rev abc)" line for a locked node.
    def pinLine(name: String, locked: Json): String =
        let date = match JsonUtil.getKey("lastModified", locked) {
            case Some(JNumber(ts)) => match BigDecimal.tryToInt64(ts) {
                case Some(secs) => Date.epochSecondsToIsoDate(secs)
                case None       => "?"
            }
            case _ => "?"
        };
        let rev = JsonUtil.getString("rev", locked)
            |> Option.map(r -> String.takeLeft(12, r))
            |> Option.getWithDefault("?");
        "${name}: pinned ${date} (rev ${rev})"

}
