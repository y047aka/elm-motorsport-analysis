///
/// 接続プール。HikariCP を包み、借りた接続で SqlRead / SqlWrite を走らせて必ず返す。
/// Web のように接続を使い回す所はこちら、CLI やテストのように 1 回だけ開くなら `Jdbc.withConnection`。
///
pub mod Sqlitefx.Pool {

    use Sqlitefx.Db
    use Sqlitefx.DbErr
    use Sqlitefx.DbError
    use Sqlitefx.Jdbc
    use Sqlitefx.SqlRead
    use Sqlitefx.SqlSavepoint
    use Sqlitefx.SqlWrite
    use Sqlitefx.TransientDbErr
    use Sqlitefx.Tx

    import java.lang.Throwable
    import java.sql.Connection
    import java.sql.SQLException
    import com.zaxxer.hikari.HikariConfig
    import com.zaxxer.hikari.HikariDataSource
    import com.zaxxer.hikari.HikariPoolMXBean
    import org.sqlite.SQLiteDataSource

    ///
    /// 開いたプール。`open` で作り、`close` で全接続を閉じる。
    ///
    pub enum Pool {
        case Pool(HikariDataSource, List[String])
    }

    ///
    /// プールの設定。
    ///
    /// - `connection`: 接続先と、接続ごとに送る pragma
    /// - `maxConnections`: 同時に使う接続の上限。超えた分は `borrowTimeoutMs` まで待つ
    /// - `borrowTimeoutMs`: 借りるのを待つ上限。超えたら TransientDbErr.timeout
    /// - `leakDetectionThresholdMs`: 借りたまま返さない接続を HikariCP が SLF4J の warn に出すまでの ms。0 で無効。
    ///   HikariCP は 2000 未満を黙って無効にするので、0 でなければ 2000 以上に丸める
    ///
    pub type alias PoolConfig = { connection = Jdbc.ConnectionConfig, maxConnections = Int32, borrowTimeoutMs = Int32, leakDetectionThresholdMs = Int32 }

    ///
    /// プールの数字。`/health` のような所で枯渇や漏れを見るのに使う。
    ///
    /// - `active`: 借りられている接続
    /// - `idle`: 空いている接続
    /// - `waiting`: 借りるのを待っているスレッド
    /// - `total`: 開いている接続（active + idle）
    /// - `max`: 設定の上限（`maxConnections`）
    ///
    pub type alias PoolStats = { active = Int32, idle = Int32, waiting = Int32, total = Int32, max = Int32 }

    ///
    /// 既定の設定。接続数 10、待ち 5 秒、漏れの検出は無効。
    ///
    pub def defaultConfig(connection: Jdbc.ConnectionConfig): PoolConfig =
        { connection = connection, maxConnections = 10, borrowTimeoutMs = 5000, leakDetectionThresholdMs = 0 }

    ///
    /// HikariCP が受け付ける最小の漏れ検出のしきい値（ms）。
    ///
    def minLeakDetectionThresholdMs(): Int32 = 2000

    ///
    /// プールを開く。この時点では接続しない（最初の borrow で開く）。
    ///
    /// WhyNot: `initializationFailTimeout` を -1 にするのは、既定の fail-fast だと `open` の時点で接続しに行き、
    /// 届かなければ Java の例外を投げて `TransientDbErr` の道を通らないため。届くかは最初の `borrow` で分かる。
    ///
    /// WhyNot: HikariCP に `jdbcUrl` を渡さないのは、ドライバをクラス名で探す経路が Flix の Maven クラスローダで効かないから（`Jdbc.connect` と同じ理由）。sqlite-jdbc の DataSource をこちらで作って渡す。
    ///
    pub def open(config: PoolConfig): Pool \ IO =
        let source = new SQLiteDataSource();
        source.setUrl(config#connection#url);
        let hikari = new HikariConfig();
        hikari.setDataSource(source);
        hikari.setMaximumPoolSize(config#maxConnections);
        hikari.setConnectionTimeout(Int32.toInt64(config#borrowTimeoutMs));
        hikari.setInitializationFailTimeout(-1i64);
        hikari.setLeakDetectionThreshold(Int32.toInt64(roundLeakDetectionThreshold(config#leakDetectionThresholdMs)));
        Pool.Pool(new HikariDataSource(hikari), config#connection#pragmas)

    ///
    /// 0 以下は 0（無効）、それ以外は 2000 以上に丸める。
    ///
    def roundLeakDetectionThreshold(ms: Int32): Int32 =
        if (ms <= 0) 0 else Int32.max(minLeakDetectionThresholdMs(), ms)

    ///
    /// HikariCP に渡っている漏れ検出のしきい値（ms）。0 なら無効。
    ///
    pub def leakDetectionThresholdMs(pool: Pool): Int32 \ IO =
        let Pool.Pool(source, _) = pool;
        let threshold: Int64 = source.getLeakDetectionThreshold();
        Int64.clampToInt32(min = 0, max = Int32.maxValue(), threshold)

    ///
    /// 今の数字。
    ///
    /// WhyNot: MXBean が null の時に例外にしないのは、プールがまだ 1 本も開いていない（`initializationFailTimeout` -1 で
    /// 遅延している）時や閉じた後にも `/health` は読みに来るので、その時は「0 本」と答える方が扱いやすいため。
    ///
    pub def stats(pool: Pool): PoolStats \ IO =
        let Pool.Pool(source, _) = pool;
        let max: Int32 = source.getMaximumPoolSize();
        let bean: HikariPoolMXBean = source.getHikariPoolMXBean();
        if (Object.isNull(bean))
            { active = 0, idle = 0, waiting = 0, total = 0, max = max }
        else
            { active = bean.getActiveConnections(), idle = bean.getIdleConnections(), waiting = bean.getThreadsAwaitingConnection(), total = bean.getTotalConnections(), max = max }

    ///
    /// 全接続を閉じる。終了時に 1 回。
    ///
    pub def close(pool: Pool): Unit \ IO =
        let Pool.Pool(source, _) = pool;
        source.close()

    ///
    /// 借りた接続をプールから外す。close は呼ばない（HikariCP が物理接続を別のスレッドで閉じ、SQLite がその Tx を ROLLBACK する）。
    /// fatal の後や、sqlite-jdbc の中の例外で接続の状態が分からない時に使う。自前の SqlRead / SqlWrite の handler を書く利用側向け。
    ///
    /// WhyNot: evict の後に close を呼ばない。HikariCP 5.1.0 では close が本物の接続に ROLLBACK を送るか、
    /// `PoolBase.resetConnectionState` の NullPointerException になり、fatal がその NPE にすり替わる（`TestEvictProcedure`）。
    ///
    pub def evict(pool: Pool, conn: Connection): Unit \ IO =
        let Pool.Pool(source, _) = pool;
        match Db.catchAll(() -> source.evictConnection(conn)) {
            case Ok(())     => ()
            // WhyNot: evict の失敗を投げない。呼ぶ所は元の失敗を投げ直す途中で、それを上書きしたくないため。fatal だけは投げ直す
            case Err(error) => if (Db.isFatal(error)) Db.rethrowing(Err(error)) else ()
        }

    ///
    /// 接続を借りる。上限まで使われていて `borrowTimeoutMs` 待っても空かなければ TransientDbErr.timeout、
    /// DB に繋げなければ TransientDbErr.connectionLost。
    ///
    /// 設定の pragma は借りるたびに送る。
    ///
    /// WhyNot: HikariCP の `connectionInitSql` で新しい物理接続にだけ送らないのは、それが 1 文しか実行せず、`;` で繋いだ 2 つ目以降の pragma が黙って落ちるから（`TestPool.testPooledConnectionsGetThePragmas`）。
    /// pragma 1 つは µs の桁で、借りる度に送っても借り待ちに比べて無いに等しい。
    ///
    /// WhyNot: 例外の message で分けないのは、HikariCP が「借り待ちの上限」も「DB に届かない」も
    /// 同じ "request timed out" の文言で出すため。借りに失敗した時点の `stats` と cause の連鎖で分ける。
    ///
    pub def borrow(pool: Pool): Connection \ {IO, TransientDbErr} =
        let Pool.Pool(source, pragmas) = pool;
        try {
            let conn: Connection = source.getConnection();
            try {
                Jdbc.sendPragmas(conn, pragmas);
                conn
            } catch {
                case e: SQLException => { evict(pool, conn); throw e }
            }
        } catch {
            case e: SQLException =>
                let msg: String = e.getMessage();
                let text = if (Object.isNull(msg)) "" else msg;
                TransientDbErr.raiseTransient(borrowFailureKind(text, resultCodeOf(unchecked_cast(e as Throwable), maxCauseDepth()), stats(pool)))
        }

    ///
    /// borrow が失敗した理由を分ける（純粋）。
    ///
    /// - cause の連鎖に SQLite の CANTOPEN（DB のファイルを開けない）があれば connectionLost
    /// - そうでなく pool が満杯（`active >= max`）なら timeout（借り待ちの上限）
    /// - それ以外は、pool は空いているのに接続が作れなかったので connectionLost
    ///
    pub def borrowFailureKind(message: String, resultCode: Option[Int32], poolStats: PoolStats): DbError.TransientKind =
        if (resultCode |> Option.exists(code -> Int32.remainder(code, 256) == cantOpen()))
            DbError.TransientKind.ConnectionLost(message)
        else if (poolStats#max > 0 and poolStats#active >= poolStats#max)
            DbError.TransientKind.Timeout(0)
        else
            DbError.TransientKind.ConnectionLost(message)

    /// SQLite の SQLITE_CANTOPEN。
    def cantOpen(): Int32 = 14

    ///
    /// cause の連鎖をたどる上限。
    ///
    def maxCauseDepth(): Int32 = 8

    ///
    /// 連鎖をたどって最初の sqlite-jdbc の例外（`org.sqlite.SQLiteException`）の result code を取る。
    ///
    /// WhyNot: 一番外の SQLException の `getErrorCode` を見ないのは、HikariCP が借りられなかった事を自分のSQLException で包み、ドライバの result code は cause の側に残るから。
    ///
    def resultCodeOf(t: Throwable, depth: Int32): Option[Int32] \ IO =
        if (depth <= 0 or Object.isNull(t))
            None
        else {
            let name: String = t.getClass().getName();
            if (name == "org.sqlite.SQLiteException") {
                let sqlite: SQLException = unchecked_cast(t as SQLException);
                Some(sqlite.getErrorCode())
            } else
                resultCodeOf(t.getCause(), depth - 1)
        }

    ///
    /// 接続を借りて thunk を走らせ、成功でも失敗でも必ず返す。失敗はそのまま再送出する。
    /// Tx が要るなら thunk の中で `Tx.withTx(conn, ...)`。制約違反の翻訳（`onConstraint`）は Tx の外で。
    ///
    pub def withConnection(pool: Pool, thunk: Connection -> a \ ef): a \ (ef - {SqlRead, SqlWrite, SqlSavepoint}) + {IO, TransientDbErr, DbErr} =
        runOnConnection(pool, borrow(pool), thunk)

    ///
    /// `withConnection` に、この呼び出しだけの借り待ちの上限を付けた形。上限までに借りられなければ
    /// `TransientDbErr.timeout(borrowTimeoutMs)`。ping や health check のような「待ってまで欲しくない」
    /// 借り方に使う。業務の Tx には使わない（そこで待ちが長いなら直すのは pool の設定の方なので）。
    ///
    pub def withConnectionTimeout(pool: Pool, borrowTimeoutMs: Int32, thunk: Connection -> a \ ef): a \ (ef - {SqlRead, SqlWrite, SqlSavepoint}) + {IO, TransientDbErr, DbErr} =
        match borrowWithin(pool, borrowTimeoutMs) {
            case None                 => TransientDbErr.timeout(borrowTimeoutMs)
            case Some(Err(transient)) => TransientDbErr.raiseTransient(transient)
            case Some(Ok(conn))       => runOnConnection(pool, conn, thunk)
        }

    ///
    /// 借りた接続で thunk を走らせ、成功でも失敗でも必ず返す。thunk の JVM の例外は `DbErr` の `Other`。
    /// fatal は接続を evict してから投げ直す。sqlite-jdbc の中の例外の後は、状態が分からないので返さずに evict する。
    ///
    def runOnConnection(pool: Pool, conn: Connection, thunk: Connection -> a \ ef): a \ (ef - {SqlRead, SqlWrite, SqlSavepoint}) + {IO, TransientDbErr, DbErr} =
        let watch = { onFatal = () -> evict(pool, conn), driverFailed = Ref.fresh(Static, false) };
        let outcome = Jdbc.watched(watch, () -> DbError.runWithKind(() -> Jdbc.runWithConnectionWatched(() -> conn, watch, () -> Db.guard(() -> thunk(conn)))));
        if (Ref.get(watch#driverFailed)) evict(pool, conn) else Jdbc.close(conn);
        match outcome {
            case Ok(value) => value
            case Err(kind) => DbError.raise(kind)
        }

    ///
    /// borrow を別スレッドに出し、borrowTimeoutMs だけ待つ。間に合わなければ None。
    ///
    /// WhyNot: HikariCP の `connectionTimeout` を一時的に書き換えないのは、pool は共有なので他のリクエストの
    /// 借り待ちまで一緒に縮むため。`HikariDataSource` には呼び出しごとの上限を渡す口が無い。
    ///
    /// WhyNot: Chan / NonDet を署名に出さないのは、この 2 つの実体が IO で、`/health` のような呼び出し側へ
    /// 「中でチャネルを使っている」事情を伝播させたくないため。`unchecked_cast` はエフェクトを畳むだけで値は変えない。
    ///
    def borrowWithin(pool: Pool, borrowTimeoutMs: Int32): Option[Result[DbError.TransientKind, Connection]] \ IO =
        unchecked_cast(borrowWithinChannel(pool, borrowTimeoutMs) as _ \ IO)

    ///
    /// borrowWithin の中身。
    ///
    /// WhyNot: spawn の region を `Static` にするのは、region は抜ける所で spawn したスレッドを待ち合わせるので、
    /// その場で region を開くと待ち切る意味が無くなるため。
    ///
    /// WhyNot: 待ち切れなかった時に受け取りを諦めないのは、遅れて届いた接続が誰にも返されず pool が痩せるため。
    /// 受け取り役をもう 1 本 spawn して、届いた所で閉じる。
    ///
    def borrowWithinChannel(pool: Pool, borrowTimeoutMs: Int32): Option[Result[DbError.TransientKind, Connection]] \ {IO, Chan, NonDet} =
        let (sender, receiver) = Channel.buffered(1);
        spawn Channel.send(TransientDbErr.runWithResult(() -> borrow(pool)), sender) @ Static;
        select {
            case delivered <- Channel.recv(receiver) => Some(delivered)
            case _         <- Channel.recv(Channel.timeout(Int32.max(1, borrowTimeoutMs), Time.TimeUnit.Milliseconds)) => {
                spawn closeWhenDelivered(receiver) @ Static;
                None
            }
        }

    ///
    /// 待ち切れなかった借りが遅れて届いたら閉じる。
    ///
    def closeWhenDelivered(receiver: Receiver[Result[DbError.TransientKind, Connection]]): Unit \ {IO, Chan, NonDet} =
        match Channel.recv(receiver) {
            case Ok(conn) => Jdbc.close(conn)
            case Err(_)   => ()
        }

    ///
    /// 最初の SQL が来た時に初めて接続を借りて BEGIN し、thunk が終わったら COMMIT（失敗なら ROLLBACK）して返す。
    /// SQL を 1 本も出さない thunk はプールに触らない。GraphQL のリゾルバのように「DB を使うかもしれない」単位を
    /// 1 つの Tx にしたい所で使う。ネストは `withTx` と同じく未対応。
    /// thunk が JVM の例外を投げても ROLLBACK して接続を返し、`DbErr` の `Other` として上げる
    /// （`OutOfMemoryError` のような `VirtualMachineError` はそのまま再送出）。
    ///
    pub def withLazyTx(pool: Pool, thunk: Unit -> a \ ef): a \ (ef - {SqlRead, SqlWrite, SqlSavepoint}) + {IO, TransientDbErr, DbErr} =
        withLazyTxAfterBegin(pool, () -> (), thunk)

    ///
    /// `withLazyTx` に加えて、BEGIN の直後（thunk の最初の SQL の前）に onBegin を同じ接続・同じ Tx で 1 回だけ流す。
    /// `SELECT set_config('app.tenant', $1, true)` のように、Tx の間だけ効く印を置くのに使う。
    /// SQL を出さない thunk では onBegin も呼ばれない（接続を借りないため）。
    ///
    /// WhyNot: 印を Tx の外（接続を借りた直後）で置かないのは、`set_config(..., true)` は Tx の終わりで消えるので
    /// BEGIN の後でないと効かず、プールに返した接続へ印が残る事も無いため。
    ///
    pub def withLazyTxAfterBegin(pool: Pool, onBegin: Unit -> Unit \ ef2, thunk: Unit -> a \ ef): a \ (ef - {SqlRead, SqlWrite, SqlSavepoint}) + (ef2 - {SqlRead, SqlWrite, SqlSavepoint}) + {IO, TransientDbErr, DbErr} =
        match withLazyTxResultAfterBegin(pool, onBegin, () -> Ok(thunk())) {
            case Ok(value) => value
            // WhyNot: この腕を書くのは、e が型変数のままで match が網羅を求めるため。Err は上の `Ok(...)` からは作られない
            case Err(_)    => bug!("withLazyTxAfterBegin: Err is never produced")
        }

    ///
    /// `withLazyTx` の Result 版。thunk が `Ok` を返したら COMMIT して `Ok`、`Err` を返したら ROLLBACK して
    /// その `Err` をそのまま返す。業務エラーを Tx の中で受けて巻き戻したい所で使う。
    ///
    /// ```
    /// Pool.withLazyTxResult(pool, () -> RegisterErr.runWithResult(thunk))
    /// ```
    ///
    /// WhyNot: 業務エラーを Tx の外で受けないのは、Flix の effect は再開しない時に間の frame を捨てるだけで
    /// finally が無く、外で受けると COMMIT / ROLLBACK と接続の返却が飛んで接続が漏れるため。
    ///
    pub def withLazyTxResult(pool: Pool, thunk: Unit -> Result[e, a] \ ef): Result[e, a] \ (ef - {SqlRead, SqlWrite, SqlSavepoint}) + {IO, TransientDbErr, DbErr} =
        withLazyTxResultAfterBegin(pool, () -> (), thunk)

    ///
    /// `withLazyTxResult` に加えて、BEGIN の直後に onBegin を同じ Tx で 1 回だけ流す（`withLazyTxAfterBegin` と同じ）。
    ///
    pub def withLazyTxResultAfterBegin(pool: Pool, onBegin: Unit -> Unit \ ef2, thunk: Unit -> Result[e, a] \ ef): Result[e, a] \ (ef - {SqlRead, SqlWrite, SqlSavepoint}) + (ef2 - {SqlRead, SqlWrite, SqlSavepoint}) + {IO, TransientDbErr, DbErr} =
        let slot = Ref.fresh(Static, None);
        let evictBorrowed = () -> match Ref.get(slot) {
            case Some(found) => { Ref.put(None, slot); evict(pool, found) }
            case None        => ()
        };
        let watch = { onFatal = evictBorrowed, driverFailed = Ref.fresh(Static, false) };
        // 借りた直後に slot へ置いてから BEGIN と onBegin を流す。BEGIN が失敗しても後始末が slot の接続を返せる
        let open = () -> match Ref.get(slot) {
            case Some(found) => found
            case None        => {
                let found = borrow(pool);
                Ref.put(Some(found), slot);
                Tx.begin(found);
                // 印を置く SQL は開いたばかりの接続で流す（この時点で slot は埋まっているので、再帰しない）
                Jdbc.runWithConnection(found, () -> Db.guard(onBegin));
                found
            }
        };
        // A: handler の本体の JDBC（Jdbc.runWithConnectionWatched）。B: thunk の最内側の Db.guard。
        // E: handler の run 全体を外から包む Jdbc.watched。利用側の書き方（SQL を出す関数の中で投げる、closure を record に
        // 入れる）では例外が B を飛ばして op を受けた handler の所から出てくるので、E がそれを拾う（TestCatchNesting の 9 / 10）
        let outcome = Jdbc.watched(watch, () -> DbError.runWithKind(() -> Jdbc.runWithConnectionWatched(open, watch, () -> Db.guard(thunk))));
        let finished = match Ref.get(slot) {
            case None        => outcome
            case Some(found) =>
                if (Ref.get(watch#driverFailed)) { evict(pool, found); discarded(outcome) }
                else match outcome {
                    case Ok(Ok(_)) => commitAndClose(pool, found, outcome)
                    // thunk の Err（業務エラー）も DbErr も巻き戻す
                    case _         => { rollbackAndClose(pool, found); outcome }
                }
        };
        match finished {
            case Ok(value) => value
            case Err(kind) => DbError.raise(kind)
        }

    ///
    /// sqlite-jdbc の中の例外で接続を捨てた後の結果。thunk が失敗を値で受けて `Ok` を返していても、COMMIT していないので失敗にする。
    ///
    def discarded(outcome: Result[DbError.DbErrorKind, Result[e, a]]): Result[DbError.DbErrorKind, Result[e, a]] = match outcome {
        case Ok(Ok(_)) => Err(DbError.DbErrorKind.Other("the connection was discarded after an exception inside the driver, so the transaction was not committed"))
        case _         => outcome
    }

    ///
    /// COMMIT して返す。COMMIT の失敗（直列化失敗など）は `Tx.commit` が ROLLBACK してから値にする。
    /// COMMIT の最中の fatal は、COMMIT がファイルに書かれたか分からないので marker を付け、evict してから投げ直す。
    ///
    def commitAndClose(pool: Pool, conn: Connection, outcome: Result[DbError.DbErrorKind, b]): Result[DbError.DbErrorKind, b] \ IO =
        match Db.catchAll(() -> DbError.runWithKind(() -> Tx.commit(conn))) {
            case Ok(Ok(_))    => { Jdbc.close(conn); outcome }
            case Ok(Err(kind)) => { Jdbc.close(conn); Err(kind) }
            case Err(error)   => {
                evict(pool, conn);
                if (Db.isFatal(error)) Db.rethrowing(Err(Db.markCommitOutcomeUnknown(error)))
                else Err(DbError.DbErrorKind.Other(Db.describeThrowable(error)))
            }
        }

    ///
    /// ROLLBACK して返す。ROLLBACK が失敗した接続は Tx の途中のままなので、返さずに evict する。
    ///
    def rollbackAndClose(pool: Pool, conn: Connection): Unit \ IO =
        match Db.catchAll(() -> Tx.rollback(conn)) {
            case Ok(true)   => Jdbc.close(conn)
            case Ok(false)  => evict(pool, conn)
            case Err(error) => { evict(pool, conn); if (Db.isFatal(error)) Db.rethrowing(Err(error)) else () }
        }

}
