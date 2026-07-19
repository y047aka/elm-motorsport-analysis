///
/// nix-channel-audit and nix-flakelock-audit. Port of scripts/src/nix.rs.
///
mod DepsAudit.Nix {

    use Util.Json.Json
    use Util.Json.Json.{JObject, JNumber}
    use DepsAudit.Date
    use DepsAudit.JsonUtil

    /// Render the channel report from flake.nix content and the current
    /// epoch time in seconds.
    ///
    /// Both channel spellings are recognised: the plain `nixos-YY.MM` this
    /// repository uses, and the `nixpkgs-YY.MM-darwin` form the Rust version
    /// assumed (it only matched the latter, so the audit reported
    /// `channel: unknown` on every run here).
    pub def renderChannelAudit(flakeContent: String, nowSecs: Int64): String =
        match parseChannel(flakeContent) {
            case Some((label, yy, mm)) =>
                let current = "current channel: ${channelLabel(label, yy, mm)}";
                let (nowYearFull, nowMonth, _) = Date.daysToYmd(nowSecs / 86400i64);
                let nowYear = nowYearFull - (nowYearFull / 100i64) * 100i64;
                match latestStableChannel(nowYear, nowMonth) {
                    case Some((ly, lm)) =>
                        let currentNum = yy * 100i64 + mm;
                        let latestNum = ly * 100i64 + lm;
                        let suffix = if (latestNum > currentNum) "  <- UPGRADE AVAILABLE" else "  (up to date)";
                        current + "\n" + "latest channel:  ${channelLabel(label, ly, lm)}${suffix}"
                    case None =>
                        current + "\n" + "latest channel: unknown"
                }
            case None => "channel: unknown"
        }

    /// Which spelling of the channel a flake.nix uses.
    pub enum ChannelStyle with Eq {
        case Nixos          // nixos-YY.MM
        case NixpkgsDarwin  // nixpkgs-YY.MM-darwin
    }

    /// Extract the pinned channel, trying both spellings.
    pub def parseChannel(flakeContent: String): Option[(ChannelStyle, Int64, Int64)] =
        let darwinRgx = regex"nixpkgs-(\\d+)\\.(\\d+)-darwin";
        let nixosRgx = regex"nixos-(\\d+)\\.(\\d+)";
        match Regex.capture(darwinRgx, flakeContent) {
            case yyS :: mmS :: Nil => pair(ChannelStyle.NixpkgsDarwin, yyS, mmS)
            case _ => match Regex.capture(nixosRgx, flakeContent) {
                case yyS :: mmS :: Nil => pair(ChannelStyle.Nixos, yyS, mmS)
                case _                 => None
            }
        }

    def pair(style: ChannelStyle, yyS: String, mmS: String): Option[(ChannelStyle, Int64, Int64)] =
        forM (
            yy <- Int64.fromString(yyS);
            mm <- Int64.fromString(mmS)
        ) yield (style, yy, mm)

    /// Render a channel label in the same spelling the flake uses.
    pub def channelLabel(style: ChannelStyle, yy: Int64, mm: Int64): String =
        match style {
            case ChannelStyle.Nixos         => "nixos-${yy}.${pad2(mm)}"
            case ChannelStyle.NixpkgsDarwin => "nixpkgs-${yy}.${pad2(mm)}-darwin"
        }

    /// Latest stable channel label (May/November releases from 24.05 on).
    def latestStableChannel(nowYear: Int64, nowMonth: Int64): Option[(Int64, Int64)] =
        def loop(y, acc) =
            if (y > nowYear) acc
            else {
                let acc1 = if (y < nowYear or 5i64 <= nowMonth) Some((y, 5i64)) else acc;
                let acc2 = if (y < nowYear or 11i64 <= nowMonth) Some((y, 11i64)) else acc1;
                loop(y + 1i64, acc2)
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

    def pad2(n: Int64): String =
        if (n < 10i64) "0${n}" else "${n}"

}
