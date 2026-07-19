///
/// Version-string helpers shared by the audit subcommands.
///
/// Faithful port of the semver logic in the Rust implementation
/// (scripts/src/rust_audit.rs and scripts/src/elm_pages.rs):
/// components are split on '.', unparsable components are dropped,
/// and missing components compare as 0.
///
/// `Semver` is a parsed version as a value with `Eq`/`Order`, so
/// version ordering travels with the type: sorting version strings is
/// `List.sortBy(Semver.parse)` rather than a hand-written comparator.
/// Trailing zero components are normalized away at parse time, which is
/// what makes the derived `Eq` agree with `Order` ("1.2" == "1.2.0").
///
mod DepsAudit.Semver {

    /// A parsed version: its numeric components, without trailing zeros.
    /// Only `parse` constructs one, so the normalization is an invariant.
    pub enum Semver(List[Int64]) with Eq, ToString

    instance Order[Semver] {
        pub def compare(x: Semver, y: Semver): Comparison =
            let Semver.Semver(xs) = x;
            let Semver.Semver(ys) = y;
            // Both lists are free of trailing zeros, so the longer one is
            // greater when they share a prefix — no zero-padding needed.
            Order.compare(xs, ys)
    }

    /// Parse a version string ("1.2.3" -> Semver(1 :: 2 :: 3 :: Nil)),
    /// dropping unparsable components and trailing zeros.
    pub def parse(version: String): Semver =
        Semver.Semver(components(version) |> dropTrailingZeros)

    /// Numeric components of a version string ("1.2.3" -> 1 :: 2 :: 3 :: Nil).
    pub def components(version: String): List[Int64] =
        String.splitOn({substr = "."}, version) |> List.filterMap(Int64.fromString)

    def dropTrailingZeros(parts: List[Int64]): List[Int64] =
        parts
            |> List.reverse
            |> List.dropWhile(p -> p == 0i64)
            |> List.reverse

    /// Strip leading constraint operators ("^1.2", "~1.2", ">=1.2" -> "1.2").
    pub def baseVersion(constraint: String): String =
        constraint |> String.dropWhileLeft(c ->
            c == '~' or c == '^' or c == '>' or c == '=' or c == '<')

    /// Index and value of the leftmost non-zero component ((0, 0) when all zero).
    pub def majorComponent(version: String): (Int32, Int64) =
        let parts = components(version);
        def loop(idx, rest) = match rest {
            case Nil     => (0, 0i64)
            case p :: ps => if (p != 0i64) (idx, p) else loop(idx + 1, ps)
        };
        loop(0, parts)

    /// A major bump is when the leftmost non-zero component increases
    /// (e.g. 0.8 -> 0.9, 1.x -> 2.x) or shifts position.
    pub def isMajorBump(current: String, latest: String): Bool =
        let (ci, cv) = majorComponent(current);
        let (li, lv) = majorComponent(latest);
        if (ci != li) true else lv > cv

    /// A minor bump is when the component right of the leftmost non-zero
    /// component increases. When `from` is all zeros, any non-zero `to`
    /// counts as minor.
    pub def isMinorBump(oldVersion: String, newVersion: String): Bool =
        let oldParts = components(oldVersion);
        let newParts = components(newVersion);
        match firstNonZeroIndex(oldParts) {
            case None      => List.exists(p -> p != 0i64, newParts)
            case Some(idx) =>
                let next = idx + 1;
                match (List.nth(next, oldParts), List.nth(next, newParts)) {
                    case (Some(oldC), Some(newC)) => newC > oldC
                    case _                        => false
                }
        }

    def firstNonZeroIndex(parts: List[Int64]): Option[Int32] =
        def loop(idx, rest) = match rest {
            case Nil     => None
            case p :: ps => if (p != 0i64) Some(idx) else loop(idx + 1, ps)
        };
        loop(0, parts)

}
