use Sqlitefx.DbError
use Sqlitefx.Decoder
use Sqlitefx.Jdbc
use Sqlitefx.Pool
use Sqlitefx.RawSql
use Sqlitefx.Sql

// Pool: 実 SQLite の接続を借りるテスト。

/// プールが新しく開いた接続にも、設定の pragma が全部届いている（`connectionInitSql` に `;` で繋いだ 2 つとも）。
///
///   PRAGMA foreign_keys → 1      PRAGMA busy_timeout → 5000
@Test
def testPooledConnectionsGetThePragmas(): Unit \ {Assert, IO} =
    let pool = Pool.open(Pool.defaultConfig(Jdbc.config("jdbc:sqlite:file:pooled?mode=memory&cache=shared")));
    let seen = DbError.runWithFailure(() -> RawSql.runWithAllow(() -> Pool.withConnection(pool, _ -> {
        let foreignKeys = Sql.fetchOneAs(Decoder.int32("foreign_keys"), "PRAGMA foreign_keys", Nil);
        let busyTimeout = Sql.fetchOneAs(Decoder.int32("timeout"), "PRAGMA busy_timeout", Nil);
        (foreignKeys, busyTimeout)
    })));
    Pool.close(pool);
    Assert.assertEq(expected = Ok((Some(1), Some(5000))), seen)

/// 借りた接続で書いた物が、次に借りた接続から読める（同じ DB を見ている）。
@Test
def testPooledConnectionsShareTheDatabase(): Unit \ {Assert, IO} =
    let pool = Pool.open(Pool.defaultConfig(Jdbc.config("jdbc:sqlite:file:pooledshare?mode=memory&cache=shared")));
    let seen = DbError.runWithFailure(() -> RawSql.runWithAllow(() -> {
        Pool.withConnection(pool, _ -> {
            discard Sql.execute("CREATE TABLE t (n INTEGER)", Nil);
            discard Sql.execute("INSERT INTO t VALUES (1), (2)", Nil)
        });
        Pool.withConnection(pool, _ -> Sql.fetchAs(Decoder.int32("n"), "SELECT n FROM t ORDER BY n", Nil))
    }));
    Pool.close(pool);
    Assert.assertEq(expected = Ok(List#{1, 2}), seen)
