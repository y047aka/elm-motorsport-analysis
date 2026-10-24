/// A number as the kept files print it.
///
/// A kept geometry is written by two tools in two languages, and they print a number
/// differently: JavaScript says `5515` where Flix prints a `Float64` through Java and says
/// `5515.0`, so a tool that rewrites a kept file cannot simply interpolate what it computed,
/// or every whole metre in that file becomes a changed line in review and in the fence that
/// compares one file to another.
///
/// Both printings are written on the rounding JavaScript's `toFixed` states: the nearest value
/// at that many decimals, ties away from zero — `562.25` at one decimal is `562.3`. What these
/// print is metres and drawing units, which are never negative, so a tie never has to say
/// which of two infinities it runs toward.
pub mod Util.Format {

    /// A number with `digits` decimals, as `toFixed` writes it.
    pub def fixed(digits: Int32, metres: Float64): String =
        if (metres < 0.0) "-${unsigned(digits, 0.0 - metres)}" else unsigned(digits, metres)

    /// The same, of a distance known not to run backwards: the whole part, and the
    /// decimals the caller asked for padded to their own width.
    def unsigned(digits: Int32, metres: Float64): String = {
        let scale = powerOfTen(digits);
        let scaled = Float64.truncateToInt64((metres * Int64.toFloat64(scale)) + 0.5);
        let whole = scaled / scale;
        let part = scaled - (whole * scale);
        if (digits == 0)
            "${whole}"
        else
            "${whole}.${String.repeat(digits - String.length("${part}"), "0")}${part}"
    }

    /// The same figure without a decimal point, which is how a report quotes a
    /// place along a line rather than a distance.
    pub def whole(metres: Float64): String =
        fixed(0, metres)

    /// A number as it was meant, with no decimals forced on it: what a sentence
    /// quotes when a file's own figure is the thing being reported — the length a
    /// line's metres end at, the spacing a reader asked for. Java prints `0.0` where
    /// the tools that wrote the kept files printed `0`, and a sentence about a file
    /// that ends at `0.0 m` reads as a different file than one that ends at `0 m`.
    pub def spelled(metres: Float64): String = {
        let asWhole = Float64.truncateToInt64(metres);
        if (Int64.toFloat64(asWhole) == metres) "${asWhole}" else "${metres}"
    }

    /// Ten to the `digits`, in the whole-number arithmetic a printed decimal is
    /// counted in: the scale is multiplied into a distance by the caller, which
    /// converts, and divided back out of one, which does not need to.
    def powerOfTen(digits: Int32): Int64 =
        List.foldLeft((acc, _) -> acc * 10i64, 1i64, List.repeat(digits, 1))
}
