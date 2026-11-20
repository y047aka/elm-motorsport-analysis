/// What a failure is: a kind the caller reads, rather than a sentence.
///
/// The two effects' ops are this enum's cases, and `raise` turns a value back
/// into the op it belongs to, which is what lets a handler answer with a
/// failure and a caller raise it in its own context.
pub mod Lite3fx.DbError {

    use Lite3fx.DbErr
    use Lite3fx.TransientDbErr

    /// The failures that trying again is worth trying, which is the line between
    /// a round that cannot be served now and one that cannot be served at all.
    pub enum TransientKind with Eq, Order {
        /// No database was reached at all.
        case Unreachable(String)

        /// A lock SQLite waited out rather than got: the one refusal that says
        /// the same statement may go through next time.
        case Busy(String)
    }

    /// Where the fix is. `ToString` says it in a sentence, so the wording lives
    /// here and the kind is what a caller reads.
    pub enum DbErrorKind with Eq, Order {
        /// Trying the same statement again may get past it.
        case Transient(TransientKind)

        /// The constraint, in the driver's own words: `laps.round_id` for
        /// `UNIQUE constraint failed: laps.round_id`.
        case UniqueViolation(String)
        case ForeignKeyViolation(String)
        case CheckViolation(String)

        /// The column the driver named.
        case NotNullViolation(String)

        /// A table or a column the database has not got.
        case SchemaMismatch(String)

        /// The column, and what the reading wanted of it.
        case DecodeError(String, String)

        /// A query that had to answer with a row answered with none.
        case NoRow(String)

        /// What the JVM threw rather than said.
        case Other(String)
    }

    /// The two failings in one value, which is what a boundary takes back.
    pub enum Failure with Eq {
        /// Trying the same thing again may get past it.
        case Transient(TransientKind)

        /// Trying the same thing again reaches the same failure.
        case Permanent(DbErrorKind)
    }

    instance ToString[Failure] {
        pub def toString(f: Failure): String = match f {
            case Failure.Transient(kind)  => "${kind}"
            case Failure.Permanent(kind)  => "${kind}"
        }
    }

    instance ToString[DbErrorKind] {
        pub def toString(kind: DbErrorKind): String = match kind {
            case DbErrorKind.Transient(t)           => "${t}"
            case DbErrorKind.UniqueViolation(name)  => "UNIQUE constraint failed: ${name}"
            case DbErrorKind.ForeignKeyViolation(m) => m
            case DbErrorKind.CheckViolation(name)   => "CHECK constraint failed: ${name}"
            case DbErrorKind.NotNullViolation(name) => "NOT NULL constraint failed: ${name}"
            case DbErrorKind.SchemaMismatch(m)      => m
            case DbErrorKind.DecodeError(c, detail) => "column `${c}` ${detail}"
            case DbErrorKind.NoRow(subject)         => "${subject} came back with no row"
            case DbErrorKind.Other(detail)          => detail
        }
    }

    instance ToString[TransientKind] {
        pub def toString(kind: TransientKind): String = match kind {
            case TransientKind.Unreachable(cause)  => "no database (${cause})"
            case TransientKind.Busy(cause)         => cause
        }
    }

    /// Whether trying the same statement again is worth trying, which the
    /// constructor says.
    pub def isTransient(kind: DbErrorKind): Bool = match kind {
        case DbErrorKind.Transient(_) => true
        case _                        => false
    }

    /// No database was reached at all.
    pub def unreachable(cause: String): DbErrorKind =
        DbErrorKind.Transient(TransientKind.Unreachable(cause))

    /// A lock the database waited out rather than got.
    pub def busy(cause: String): DbErrorKind =
        DbErrorKind.Transient(TransientKind.Busy(cause))

    /// A cell the reading could not read.
    pub def decodeError(column: String, detail: String): DbErrorKind =
        DbErrorKind.DecodeError(column, detail)

    /// The failure, out of whichever effect carried it.
    pub def toFailure(kind: DbErrorKind): Failure = match kind {
        case DbErrorKind.Transient(t) => Failure.Transient(t)
        case _                        => Failure.Permanent(kind)
    }

    /// The failure, as whichever of the two effects carries it.
    pub def raise(kind: DbErrorKind): a \ {TransientDbErr, DbErr} =
        if (isTransient(kind)) TransientDbErr.raise(kind) else DbErr.raise(kind)

    /// The statements `f` sends kept and the failure it raised, as a value.
    pub def runWithKind(f: Unit -> a \ ef): Result[DbErrorKind, a] \ (ef - {TransientDbErr, DbErr}) =
        let outcome = run {
            run {
                Ok(Lite3fx.Db.catchAll(f))
            } with handler DbErr {
                def raise(kind, _k) = Err(kind)
            }
        } with handler TransientDbErr {
            def raise(kind, _k) = Err(kind)
        };
        Result.map(Lite3fx.Db.rethrowing, outcome)

    /// The failure, whichever of the two effects carried it. This is where a
    /// reading stops being a value and starts being a `Result`.
    pub def runWithFailure(f: Unit -> a \ ef): Result[Failure, a] \ (ef - {TransientDbErr, DbErr}) =
        runWithKind(f) |> Result.mapErr(toFailure)

}
