pub mod Db.Retry {

    import java.lang.Thread
    import java.util.concurrent.ThreadLocalRandom

    use Util.Duration

    /// How many tries an operation gets, and the shape of the wait between them:
    /// tries, the base wait, and the ceiling it never passes.
    pub enum Config {
        case Config(Int32, Duration, Duration)
    }

    pub def default(): Config =
        Config.Config(4, Util.Duration.fromMillis(1000), Util.Duration.fromMillis(30000))

    /// A configuration that waits nothing between its tries.
    pub def immediate(tries: Int32): Config =
        Config.Config(tries, Util.Duration.zero(), Util.Duration.zero())

    pub def tries(c: Config): Int32 = let Config.Config(n, _, _) = c; n
    pub def base(c: Config): Duration = let Config.Config(_, b, _) = c; b
    pub def cap(c: Config): Duration = let Config.Config(_, _, k) = c; k

    /// `step` doubled `left` times, stopping at `stop` rather than overflowing.
    def doubled(step: Int32, stop: Int32, left: Int32): Int32 =
        if (left <= 0)
            step
        else if (step >= stop)
            step
        else doubled(if (step > stop / 2) stop else step * 2, stop, left - 1)

    /// Exponential backoff with full jitter: a try waits a duration drawn
    /// uniformly from `[0, min(cap, base * 2^attempt)]`, which is what keeps
    /// several processes refused at the same instant from coming back at the
    /// same instant. `jitter` is that draw, out of a thousand.
    pub def backoff(attempt: Int32, c: Config, jitter: Int32): Duration = {
        let stop = Util.Duration.millis(cap(c));
        let window = doubled(Util.Duration.millis(base(c)), stop, attempt);
        Util.Duration.fromMillis(window * clamp(jitter) / 1000)
    }

    /// The draw, kept inside `[0, 999]` so a caller's arithmetic cannot go
    /// negative or reach the whole window.
    def clamp(jitter: Int32): Int32 =
        if (jitter < 0) 0 else if (jitter > 999) 999 else jitter

    /// Whether trying the same statement again could get past.
    def worthTrying(failure: Db.Failure): Bool =
        match failure {
            case Db.Failure.Transient(_) => true
            case Db.Failure.Permanent(_) => false
        }

    /// The wait between tries, and the draw the jitter is made from. Both are given
    /// rather than reached for: the trying is then driven without sleeping, and the
    /// backoff tested at a draw chosen by the test.
    pub def retryingWith(
        c: Config,
        wait: Int32 -> Unit \ ef2,
        jitter: Unit -> Int32 \ ef3,
        f: Unit -> a \ ef
    ): Result[Db.Failure, a] \ ((ef - {TransientDbErr, DbErr}) + ef2 + ef3) =
        loopWith(c, 1, wait, jitter, f)

    def loopWith(
        c: Config,
        attempt: Int32,
        wait: Int32 -> Unit \ ef2,
        jitter: Unit -> Int32 \ ef3,
        f: Unit -> a \ ef
    ): Result[Db.Failure, a] \ ((ef - {TransientDbErr, DbErr}) + ef2 + ef3) =
        match Db.attempt(f) {
            case Ok(v) => Ok(v)
            case Err(failure) =>
                if (attempt >= tries(c) or not worthTrying(failure))
                    Err(failure)
                else {
                    wait(Util.Duration.millis(backoff(attempt, c, jitter())));
                    loopWith(c, attempt + 1, wait, jitter, f)
                }
        }

    /// `f` is tried until it answers or its tries run out, waiting on the current
    /// thread and drawing its jitter as it goes.
    ///
    /// Only a transient failure is worth another try; a permanent one comes back
    /// at once. A `Busy` failure is retried here, which is only right when `f`
    /// opens the transaction itself -- see `retryingSavepoint`.
    pub def retrying(c: Config, f: Unit -> a \ ef): Result[Db.Failure, a] \ ((ef - {TransientDbErr, DbErr}) + IO) =
        retryingWith(c, sleepMs, draw, f)

    def sleepMs(ms: Int32): Unit \ IO =
        Thread.sleep(Int32.toInt64(ms))

    /// The jitter's draw, out of a thousand.
    def draw(): Int32 \ IO =
        ThreadLocalRandom.current().nextInt(1000)

    /// A savepoint is marked inside the transaction and taken back to before the
    /// next try, so the work of the failed try is gone rather than sitting in the
    /// transaction waiting for a rollback that will not come.
    pub def retryingSavepoint(
        name: String,
        c: Config,
        f: Unit -> a \ ef
    ): Result[Db.Failure, a] \ (ef + Db + IO) =
        retryingSavepointWith(name, c, sleepMs, draw, f)

    /// As `retryingWith`, of a savepoint.
    pub def retryingSavepointWith(
        name: String,
        c: Config,
        wait: Int32 -> Unit \ ef2,
        jitter: Unit -> Int32 \ ef3,
        f: Unit -> a \ ef
    ): Result[Db.Failure, a] \ (ef + Db + ef2 + ef3) =
        loopSavepoint(name, c, 1, wait, jitter, f)

    def loopSavepoint(
        name: String,
        c: Config,
        attempt: Int32,
        wait: Int32 -> Unit \ ef2,
        jitter: Unit -> Int32 \ ef3,
        f: Unit -> a \ ef
    ): Result[Db.Failure, a] \ (ef + Db + ef2 + ef3) =
        match Db.withSavepoint(name, f) {
            case Ok(v) => Ok(v)
            case Err(failure) =>
                if (attempt >= tries(c) or not worthTrying(failure))
                    Err(failure)
                else {
                    wait(Util.Duration.millis(backoff(attempt, c, jitter())));
                    loopSavepoint(name, c, attempt + 1, wait, jitter, f)
                }
        }

}
