/// What the JVM throws, and where it becomes a failure of the database.
///
/// The driver is reached through interop and the exceptions it throws are not
/// all `SQLException`; without `guard` one escapes every handler the caller had
/// installed.
pub mod Lite3fx.Db {

    use Lite3fx.TransientDbErr
    use Lite3fx.DbErr
    use Lite3fx.DbError.DbErrorKind

    import java.lang.StackOverflowError
    import java.lang.Throwable
    import java.lang.VirtualMachineError

    /// The failure, whichever of the two effects carried it. This is where a
    /// reading stops being a value and starts being a `Result`.
    pub def attempt(f: Unit -> a \ ef): Result[Lite3fx.DbError.Failure, a] \ (ef - {TransientDbErr, DbErr}) =
        Lite3fx.DbError.runWithFailure(f)

    /// `f` run, and whatever it threw kept as a value -- the same throwable,
    /// untouched. Whether it was a database's failure or the JVM's is the
    /// caller's to decide, and a fatal one is not a failure to keep.
    ///
    /// The throw comes back after the `run` has been left: what is thrown from
    /// inside a `run` passes every catch the caller had put outside it.
    pub def catchAll(f: Unit -> a \ ef): Result[Throwable, a] \ ef =
        try {
            Ok(f())
        } catch {
            case error: Throwable => Err(error)
        }

    /// A throwable kept as a value thrown again -- the same one, not a copy of
    /// it and not wrapped in another.
    ///
    /// The throwing is not in the signature: what comes out is what the caller
    /// already threw.
    pub def rethrowing(outcome: Result[Throwable, a]): a = match outcome {
        case Ok(value)  => value
        case Err(error) => unchecked_cast(throwAgain(error) as _ \ {})
    }

    def throwAgain(error: Throwable): a \ IO = throw error

    /// Something the JVM cannot go on past. The cause chain is walked because a
    /// driver or a future can wrap an `OutOfMemoryError` in something that is
    /// not fatal to look at from the outside.
    pub def isFatal(error: Throwable): Bool \ IO =
        isFatalWithin(error, 0)

    /// How far down to look before concluding the chain has no fatal end: a
    /// throwable that carries itself as its own cause has to stop somewhere.
    def maxCauseDepth(): Int32 = 8

    def isFatalWithin(error: Throwable, depth: Int32): Bool \ IO =
        if (isFatalItself(error)) true
        else {
            let cause = error.getCause();
            if (Object.isNull(cause) or depth >= maxCauseDepth()) false
            else isFatalWithin(cause, depth + 1)
        }

    /// `StackOverflowError` is a `VirtualMachineError` and is not fatal here: one
    /// reading recursing too deeply is a failure its caller can be taken back
    /// from, and the JVM goes on.
    ///
    /// Thrown and caught rather than tested, since Flix has no type predicate
    /// and a `catch` puts a subclass ahead of the one under it.
    def isFatalItself(error: Throwable): Bool \ IO =
        try {
            throw error
        } catch {
            case _: StackOverflowError  => false
            case _: VirtualMachineError => true
            case _: Throwable           => false
        }

    /// What a throwable says. Some of what the driver throws says nothing, and
    /// `null` is not a sentence to put in a failure.
    pub def describeThrowable(error: Throwable): String \ IO =
        let message: String = error.getMessage();
        if (Object.isNull(message)) error.getClass().getName() else message

    /// What the JVM threw, as a failure of the database. A failure the JVM cannot
    /// go on past is thrown again rather than turned into a value.
    pub def guard(f: Unit -> a \ ef): a \ ef + IO + DbErr =
        match catchAll(f) {
            case Ok(value)  => value
            case Err(error) =>
                if (isFatal(error)) rethrowing(Err(error))
                else DbErr.raise(DbErrorKind.Other(describeThrowable(error)))
        }

}
