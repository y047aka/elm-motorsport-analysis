///
/// Civil-date conversion, ported verbatim from the Rust implementation
/// (scripts/src/nix.rs), which in turn follows
/// http://howardhinnant.github.io/date_algorithms.html
///
mod DepsAudit.Date {

    /// Convert days since the Unix epoch to (year, month, day).
    pub def daysToYmd(days: Int64): (Int64, Int64, Int64) =
        let z = days + 719468i64;
        let era = (if (z >= 0i64) z else z - 146096i64) / 146097i64;
        let doe = z - era * 146097i64;
        let yoe = (doe - doe / 1460i64 + doe / 36524i64 - doe / 146096i64) / 365i64;
        let y0 = yoe + era * 400i64;
        let doy = doe - (365i64 * yoe + yoe / 4i64 - yoe / 100i64);
        let mp = (5i64 * doy + 2i64) / 153i64;
        let d = doy - (153i64 * mp + 2i64) / 5i64 + 1i64;
        let m = if (mp < 10i64) mp + 3i64 else mp - 9i64;
        let y = if (m <= 2i64) y0 + 1i64 else y0;
        (y, m, d)

    /// Format an epoch-seconds timestamp as "YYYY-MM-DD".
    pub def epochSecondsToIsoDate(secs: Int64): String =
        let (y, m, d) = daysToYmd(secs / 86400i64);
        "${padYear(y)}-${pad2(m)}-${pad2(d)}"

    def pad2(n: Int64): String =
        if (n < 10i64) "0${n}" else "${n}"

    def padYear(n: Int64): String =
        if (n < 10i64) "000${n}"
        else if (n < 100i64) "00${n}"
        else if (n < 1000i64) "0${n}"
        else "${n}"

}
