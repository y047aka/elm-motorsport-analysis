///
/// rust-major-audit: compare Cargo.toml version constraints against the
/// latest crates.io releases.
///
mod DepsAudit.RustMajor {

    use DepsAudit.Report
    use DepsAudit.Semver

    /// The Cargo.toml files scanned, in order.
    pub def cargoTomlFiles(): List[String] =
        "app/src-tauri/Cargo.toml" :: Nil

    /// Parse (name, constraint) pairs from Cargo.toml contents,
    /// first occurrence wins, sorted by name.
    pub def parseDeps(contents: List[String]): List[(String, String)] =
        let all = contents |> List.flatMap(parseCargoToml);
        let (_, deduped) = List.foldLeft((acc, entry) -> {
            let (seen, kept) = acc;
            let (name, _) = entry;
            if (Set.memberOf(name, seen)) acc else (Set.insert(name, seen), entry :: kept)
        }, (Set.empty(), Nil), all);
        deduped |> List.sortBy(fst)

    def parseCargoToml(content: String): List[(String, String)] =
        let sectionRgx = regex"^\\[(workspace\\.)?(dev-)?dependencies\\]";
        let anySectionRgx = regex"^\\[";
        let simpleRgx = regex"^([\\w-]+)\\s*=\\s*\"([^\"]+)\"";
        let tableRgx = regex"^([\\w-]+)\\s*=\\s*.*version\\s*=\\s*\"([^\"]+)\"";
        let step = (acc, line) -> {
            let (inDeps, found) = acc;
            if (Regex.isSubmatch(sectionRgx, line))
                (true, found)
            else if (Regex.isSubmatch(anySectionRgx, line))
                (false, found)
            else if (not inDeps)
                (inDeps, found)
            else match Regex.capture(simpleRgx, line) {
                case name :: constraint :: Nil => (inDeps, (name, constraint) :: found)
                case _ => match Regex.capture(tableRgx, line) {
                    case name :: constraint :: Nil => (inDeps, (name, constraint) :: found)
                    case _                         => (inDeps, found)
                }
            }
        };
        let (_, found) = String.splitOn({substr = "\n"}, content) |> List.foldLeft(step, (false, Nil));
        List.reverse(found)

    /// Latest version from one `cargo search <name> --limit 1` output.
    /// The line must start with the crate name (with '-' and '_' treated
    /// as equivalent), and the version is the first double-quoted string
    /// on that line.
    ///
    /// *First*, not last: a greedy `.*"([^"]+)"` picks the last quoted run
    /// on the line, which is a word from the description whenever the
    /// description contains quotes.
    pub def parseSearchOutput(name: String, output: String): Option[String] =
        String.splitOn({substr = "\n"}, output)
            |> List.findMap(line -> {
                let leadingName = String.takeWhileLeft(c -> c != ' ' and c != '\t', line);
                if (normalize(leadingName) == normalize(name) and String.length(leadingName) < String.length(line))
                    firstQuoted(line)
                else
                    None
            })

    def normalize(s: String): String =
        String.replace({src = "-"}, {dst = "_"}, s)

    def firstQuoted(line: String): Option[String] =
        match String.splitOn({substr = "\""}, line) {
            case _ :: quoted :: _ => Some(quoted)
            case _                => None
        }

    /// Render the final report given resolved (name, constraint, latest).
    pub def renderMajorAudit(resolved: List[(String, String, Option[String])]): String =
        let classify = match (name, constraint, latest) -> {
            let current = Semver.baseVersion(constraint);
            match latest {
                case Some(lat) =>
                    if (Semver.isMajorBump(current, lat))
                        (Some("${name}: ${current} -> ${lat}"), None)
                    else
                        (None, Some("${name}: ${current} (latest ${lat})"))
                case None => (None, Some("${name}: ${current} (latest unknown)"))
            }
        };
        let classified = resolved |> List.map(classify);
        let majors = classified |> List.filterMap(match (m, _) -> m);
        let upToDate = classified |> List.filterMap(match (_, u) -> u);
        Report.sections(
            ("major updates", Report.linesOrNone(majors)) ::
            ("up to date", Report.linesOrNone(upToDate)) :: Nil)

}
