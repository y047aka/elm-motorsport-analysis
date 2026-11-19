/// What the JVM throws, as opposed to what the database says.
///
/// Each test is one handler: the thing being checked is where a throw lands
/// relative to the `run` that has the handlers installed.
pub mod Db.TestGuard {
    use Lite3fx.DbError
    use Lite3fx.DbError.DbErrorKind
    use Lite3fx.DbError.Failure

    import java.lang.IllegalStateException
    import java.lang.OutOfMemoryError
    import java.lang.StackOverflowError
    import java.lang.Throwable
    import java.util.concurrent.CompletionException

    def thrown(message: String): a \ IO =
        throw new IllegalStateException(message)

    def fatal(): a \ IO =
        throw new OutOfMemoryError("cannot allocate")

    @Test
    def aDriverThatThrowsRatherThanAnswersIsAFailureOfTheDatabase(): Unit \ {Assert, IO} =
        let outcome = DbError.runWithFailure(() -> (Lite3fx.Db.guard(() -> thrown("boom")): Unit));
        Assert.assertTrue(outcome == Err(Failure.Permanent(DbErrorKind.Other("boom"))))

    /// Some of what the driver throws says nothing, and `null` is not a
    /// sentence to put in a failure.
    @Test
    def aFailureWithNoWordsIsNamedByItsClass(): Unit \ {Assert, IO} =
        Assert.assertTrue(
            Lite3fx.Db.describeThrowable(checked_cast(new IllegalStateException())) == "java.lang.IllegalStateException")

    /// The one that reaches the caller is wrapped in something that is not
    /// fatal to look at from the outside.
    @Test
    def whichFailingsTheJvmCannotGoOnPast(): Unit \ {Assert, IO} =
        let error: Throwable = checked_cast(new OutOfMemoryError("cannot allocate"));
        Assert.assertTrue(Lite3fx.Db.isFatal(error));
        Assert.assertTrue(Lite3fx.Db.isFatal(checked_cast(new CompletionException(error))));
        Assert.assertTrue(not(Lite3fx.Db.isFatal(checked_cast(new IllegalStateException("boom")))));
        // A reading that recursed too deeply is a failure its caller is taken
        // back from, and the JVM goes on.
        Assert.assertTrue(not(Lite3fx.Db.isFatal(checked_cast(new StackOverflowError()))))

    @Test
    def aFailureTheJvmCannotGoOnPastIsThrownAgain(): Unit \ {Assert, IO} =
        Assert.assertTrue(
            match Lite3fx.Db.catchAll(() -> (DbError.runWithKind(() -> Lite3fx.Db.guard(() -> fatal())): Result[DbErrorKind, Unit])) {
                case Err(error) => Lite3fx.Db.isFatal(error)
                case Ok(_)      => false
            })

    /// The throw comes back after the `run` has been left, so a caller that
    /// installed the handlers still sees it rather than passing it by.
    @Test
    def aThrowFromTheReadingTravelsPastTheHandlersToTheCaller(): Unit \ {Assert, IO} =
        Assert.assertTrue(
            match Lite3fx.Db.catchAll(() -> (DbError.runWithFailure(() -> thrown("boom")): Result[Failure, Unit])) {
                case Err(error) => Lite3fx.Db.describeThrowable(error) == "boom"
                case Ok(_)      => false
            })

    /// What the caller threw and what the database said are different kinds of
    /// thing at the boundary: one is still a throw, the other a value.
    @Test
    def aFailureOfTheDatabaseIsAValueAndNotAThrow(): Unit \ Assert =
        Assert.assertTrue(
            match Lite3fx.Db.catchAll(() -> (DbError.runWithFailure(() -> DbError.raise(DbErrorKind.Other("no such table"))): Result[Failure, Unit])) {
                case Ok(Err(Failure.Permanent(DbErrorKind.Other(_)))) => true
                case _                                                  => false
            })

}
