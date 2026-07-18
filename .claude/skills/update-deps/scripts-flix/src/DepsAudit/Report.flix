///
/// Shared report-body formatting, matching the section style of the Rust
/// implementation byte for byte. Delivery to the terminal is `DepsAudit.Cli`.
///
mod DepsAudit.Report {

    /// Render a list as newline-joined lines, or "none" when empty.
    pub def linesOrNone(lines: List[String]): String =
        if (List.isEmpty(lines)) "none" else List.join("\n", lines)

}
