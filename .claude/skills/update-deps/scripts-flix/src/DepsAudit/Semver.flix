///
/// Version-string helpers shared by the audit subcommands.
///
/// Faithful port of the semver logic in the Rust implementation
/// (scripts/src/rust_audit.rs and scripts/src/elm_pages.rs):
/// components are split on '.', unparsable components are dropped,
/// and missing components compare as 0.
///
mod DepsAudit.Semver {

    /// Numeric components of a version string ("1.2.3" -> 1 :: 2 :: 3 :: Nil).
    pub def components(version: String): List[Int64] =
        String.splitOn({substr = "."}, version) |> List.filterMap(Int64.fromString)

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
        let fp = components(oldVersion);
        let tp = components(newVersion);
        match firstNonZeroIndex(fp) {
            case None      => List.exists(p -> p != 0i64, tp)
            case Some(idx) =>
                let next = idx + 1;
                match (List.nth(next, fp), List.nth(next, tp)) {
                    case (Some(f), Some(t)) => t > f
                    case _                  => false
                }
        }

    /// Numeric comparison of version strings; missing components are 0.
    pub def compareSemver(a: String, b: String): Comparison =
        let pa = components(a);
        let pb = components(b);
        def loop(xs, ys) = match (xs, ys) {
            case (Nil, Nil)           => Comparison.EqualTo
            case (x :: xr, Nil)       => if (x != 0i64) Comparison.GreaterThan else loop(xr, Nil)
            case (Nil, y :: yr)       => if (y != 0i64) Comparison.LessThan else loop(Nil, yr)
            case (x :: xr, y :: yr)   =>
                if (x > y) Comparison.GreaterThan
                else if (x < y) Comparison.LessThan
                else loop(xr, yr)
        };
        loop(pa, pb)

    def firstNonZeroIndex(parts: List[Int64]): Option[Int32] =
        def loop(idx, rest) = match rest {
            case Nil     => None
            case p :: ps => if (p != 0i64) Some(idx) else loop(idx + 1, ps)
        };
        loop(0, parts)

}
