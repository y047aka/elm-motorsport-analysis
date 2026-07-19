///
/// rust-minor-audit: classify `cargo update --dry-run` output into minor
/// and patch updates. Port of scripts/src/rust_audit.rs (minor_audit).
///
mod DepsAudit.RustAudit {

    use DepsAudit.Report
    use DepsAudit.Semver

    /// Render the full report for the given stdin content.
    pub def renderMinorAudit(input: String): String =
        let updates =
            String.splitOn({substr = "\n"}, String.trim(input))
                |> List.filterMap(parseUpdateLine);
        let minor = updates
            |> List.filterMap(match (name, oldV, newV) ->
                if (Semver.isMinorBump(oldV, newV)) Some("${name}: ${oldV} -> ${newV}") else None);
        let patch = updates
            |> List.filterMap(match (name, oldV, newV) ->
                if (Semver.isMinorBump(oldV, newV)) None else Some("${name}: ${oldV} -> ${newV}"));
        Report.sections(
            ("minor updates", Report.linesOrNone(minor)) ::
            ("patch updates", Report.linesOrNone(patch)) ::
            ("summary", "minor: ${List.length(minor)}, patch: ${List.length(patch)}") :: Nil)

    /// Parse one "Updating foo v1.2.3 -> v1.2.4" line.
    ///
    /// The leading indentation is optional (`\s*`, not `\s+`): the input is
    /// trimmed as a whole before splitting, which strips the first line's
    /// indentation. Requiring it — as the Rust version did — silently
    /// dropped that line whenever it carried an update.
    def parseUpdateLine(line: String): Option[(String, String, String)] =
        let rgx = regex"^\\s*(?:Updating|Locking)\\s+(\\S+)\\s+v(\\S+)\\s+->\\s+v(\\S+)";
        match Regex.capture(rgx, line) {
            case name :: oldV :: newV :: Nil => Some((name, oldV, newV))
            case _                           => None
        }

}
