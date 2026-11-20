/// A value a `?` binds, or a cell came back as, in the type the driver answers
/// in.
///
/// The same enum goes out and comes back, so the type table between Flix and
/// JDBC is one table. SQLite's typing is per value rather than per column, so a
/// cell is what the driver found and not what the schema declared: a reading
/// takes what it can and says what it wanted in the failure it answers with.
pub mod Lite3fx.SqlValue {

    /// A SQL `NULL` with no type on it, which is what a cell comes back as.
    /// `NullOf` is the one a placeholder is bound with, since `setNull` is
    /// asked which type it is null of.
    pub enum SqlValue with Eq, Order {
        case Null
        case NullOf(NullType)
        case Bool(Bool)
        case Int32(Int32)
        case Int64(Int64)
        case Float64(Float64)
        case Str(String)
        /// JSON as the text the column holds, which is what `json_each` reads a
        /// row per element out of.
        case Json(String)
    }

    /// The type a `null` is bound as, which is what JDBC's `setNull` asks for.
    pub enum NullType with Eq, Order, ToString {
        case Bool
        case Int32
        case Int64
        case Float64
        case Str
        case Json
    }

    instance ToString[SqlValue] {
        pub def toString(value: SqlValue): String = match value {
            case SqlValue.Null         => "null"
            case SqlValue.NullOf(t)    => "null::${t}"
            case SqlValue.Bool(b)      => if (b) "1" else "0"
            case SqlValue.Int32(n)     => "${n}"
            case SqlValue.Int64(n)     => "${n}"
            case SqlValue.Float64(n)   => "${n}"
            case SqlValue.Str(s)       => s
            case SqlValue.Json(text)   => text
        }
    }

    /// A value that may be absent, which is what a nullable column binds: the
    /// absence is typed, so it is a `NULL` of the column's own type rather than
    /// of no type at all.
    pub def ofOption(nullType: NullType, option: Option[SqlValue]): SqlValue =
        match option {
            case Some(v) => v
            case None    => SqlValue.NullOf(nullType)
        }

    /// Whether the cell carries nothing.
    pub def isNull(value: SqlValue): Bool = match value {
        case SqlValue.Null      => true
        case SqlValue.NullOf(_) => true
        case _                  => false
    }

    /// The text a cell carries, which is what every column of this schema was
    /// written as: the load binds text, and SQLite keeps what it is given. A
    /// null has no text, and the answer for one is the empty string.
    pub def textOf(value: SqlValue): String = match value {
        case SqlValue.Str(s)     => s
        case SqlValue.Json(text) => text
        case SqlValue.Int32(n)   => "${n}"
        case SqlValue.Int64(n)   => "${n}"
        case SqlValue.Float64(n) => "${n}"
        case SqlValue.Bool(b)    => if (b) "1" else "0"
        case SqlValue.Null       => ""
        case SqlValue.NullOf(_)  => ""
    }

    /// The number a cell carries, where the driver answered it in a wider type
    /// than the column holds. Beyond what an `int` column holds there is no
    /// number to give, and the answer is none rather than a wrapped-around one.
    pub def int32Of(value: SqlValue): Option[Int32] = match value {
        case SqlValue.Int32(n)   => Some(n)
        case SqlValue.Int64(n)   =>
            if (n >= Int32.minValue() |> Int32.toInt64 and n <= Int32.maxValue() |> Int32.toInt64)
                Some(Int64.clampToInt32(min = Int32.minValue(), max = Int32.maxValue(), n))
            else
                None
        case SqlValue.Bool(true) => Some(1)
        case SqlValue.Bool(false) => Some(0)
        case _                   => Int32.fromString(textOf(value))
    }

}
