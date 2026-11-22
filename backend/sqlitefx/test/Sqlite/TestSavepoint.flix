use Sqlitefx.DbErr
use Sqlitefx.DbError
use Sqlitefx.DbWrite
use Sqlitefx.Decoder
use Sqlitefx.Jdbc
use Sqlitefx.Pool
use Sqlitefx.RawSql
use Sqlitefx.Sql
use Sqlitefx.SqlValue
use Sqlitefx.Tx

use Sqlitefx.SqlValue.SqlValue
use Sqlitefx.DbError.DbErrorKind
use Sqlitefx.DbError.Failure

// Tx.withSavepoint を実 SQLite で: 中の失敗が外の Tx に及ばない事、中の INSERT が戻る事、入れ子。
//
// WhyNot: PG の版にある statement_timeout と set_config の巻き戻しを並べないのは、SQLite に文の時間切れも
// Tx の中だけ効く設定も無いから。

/// 大きさ 1 のプールと、name が UNIQUE の表。テストごとに別の DB。
def savepointPool(name: String): Pool.Pool \ IO =
    let pool = Pool.open({ maxConnections = 1 | Pool.defaultConfig(Jdbc.config("jdbc:sqlite:file:${name}?mode=memory&cache=shared")) });
    let created = RawSql.runWithAllow(() -> DbError.runWithFailure(() -> Pool.withConnection(pool, _ ->
        discard Sql.execute("CREATE TABLE sqlitefx_test_savepoints (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE)", Nil))));
    match created { case Ok(()) => pool case Err(failure) => bug!("setup failed: ${failure}") }

def insertRow(name: String): Unit \ DbWrite + RawSql =
    discard Sql.execute("INSERT INTO sqlitefx_test_savepoints (name) VALUES ($1)", List#{SqlValue.Str(name)})

/// 表の name を id 順に。
def names(pool: Pool.Pool): Result[Failure, List[String]] \ IO =
    RawSql.runWithAllow(() -> DbError.runWithFailure(() -> Pool.withConnection(pool, _ ->
        Sql.fetchAs(Decoder.str("name"), "SELECT name FROM sqlitefx_test_savepoints ORDER BY id", Nil))))

/// 中の INSERT は ROLLBACK TO で消え、外の INSERT は残る。中の失敗は unique 違反（違反した列付きで値になる）。
///
///   INSERT outer  SAVEPOINT s [INSERT inner  INSERT inner（重複）]  ROLLBACK TO s  COMMIT … 行は outer だけ
@Test
def testSavepointDiscardsInnerInsertKeepsOuter(): Unit \ {Assert, IO} =
    let pool = savepointPool("savepoint_inner");
    let outcome = RawSql.runWithAllow(() -> DbError.runWithFailure(() -> Pool.withLazyTx(pool, () -> {
        insertRow("outer");
        Tx.withSavepoint("s", () -> {
            insertRow("inner");
            insertRow("inner")
        })
    })));
    let seen = names(pool);
    Pool.close(pool);
    Assert.assertEq(
        expected = (Ok(Err(Failure.Permanent(DbErrorKind.UniqueViolation("sqlitefx_test_savepoints.name")))), Ok(List#{"outer"})),
        (outcome, seen))

/// 入れ子: 内側の失敗は内側の SAVEPOINT までしか戻さず、外側は続きを書いて RELEASE できる。
///
///   SAVEPOINT outer_sp [INSERT x  SAVEPOINT inner_sp [INSERT y  DbErr.other]  ROLLBACK TO inner_sp  INSERT z]  RELEASE outer_sp  COMMIT
///   … Ok(Ok(Err(other boom)))、行は x, z
@Test
def testSavepointNestedInnerFailureKeepsOuter(): Unit \ {Assert, IO} =
    let pool = savepointPool("savepoint_nested_inner");
    let outcome = RawSql.runWithAllow(() -> DbError.runWithFailure(() -> Pool.withLazyTx(pool, () ->
        Tx.withSavepoint("outer_sp", () -> {
            insertRow("x");
            let inner: Result[Failure, Unit] = Tx.withSavepoint("inner_sp", () -> {
                insertRow("y");
                DbErr.other("boom")
            });
            insertRow("z");
            inner |> Result.mapErr(DbError.describeFailure)
        }))));
    let seen = names(pool);
    Pool.close(pool);
    Assert.assertEq(expected = (Ok(Ok(Err("other boom"))), Ok(List#{"x", "z"})), (outcome, seen))

/// 入れ子: 内側が RELEASE 済みでも、外側の失敗は内側の書き込みごと戻す。
///
///   INSERT before  SAVEPOINT outer_sp [SAVEPOINT inner_sp [INSERT y] RELEASE inner_sp  DbErr.other]  ROLLBACK TO outer_sp  COMMIT … 行は before だけ
@Test
def testSavepointNestedOuterFailureDiscardsReleasedInner(): Unit \ {Assert, IO} =
    let pool = savepointPool("savepoint_nested_outer");
    let outcome = RawSql.runWithAllow(() -> DbError.runWithFailure(() -> Pool.withLazyTx(pool, () -> {
        insertRow("before");
        let outer: Result[Failure, Unit] = Tx.withSavepoint("outer_sp", () -> {
            discard Tx.withSavepoint("inner_sp", () -> insertRow("y"));
            DbErr.other("boom")
        });
        outer |> Result.mapErr(DbError.describeFailure)
    })));
    let seen = names(pool);
    Pool.close(pool);
    Assert.assertEq(expected = (Ok(Err("other boom")), Ok(List#{"before"})), (outcome, seen))

/// 中の失敗を値にした後に外で SQL を出さずに終えても COMMIT され、`DbErr.rollback` にならない。
///
///   INSERT c  SAVEPOINT s [INSERT c（重複）]  ROLLBACK TO s  "done"  COMMIT … Ok(("done", true))、行は c
@Test
def testSavepointFailureDoesNotLeaveTxAborted(): Unit \ {Assert, IO} =
    let pool = savepointPool("savepoint_not_aborted");
    let outcome = RawSql.runWithAllow(() -> DbError.runWithFailure(() -> Pool.withLazyTx(pool, () -> {
        insertRow("c");
        let duplicated = Tx.withSavepoint("s", () -> insertRow("c"));
        ("done", Result.isErr(duplicated))
    })));
    let seen = names(pool);
    Pool.close(pool);
    Assert.assertEq(expected = (Ok(("done", true)), Ok(List#{"c"})), (outcome, seen))

/// Tx の中で `Db.attempt` 等で失敗を値にしても、SQLite は失敗した文だけを戻すので、前の INSERT は COMMIT される。
/// PG なら aborted になって `DbErr.rollback` になる形（`Tx.commit` の WhyNot）。
///
///   INSERT d  INSERT d（重複、値にする）  COMMIT … 行は d
@Test
def testFailedStatementDoesNotAbortTx(): Unit \ {Assert, IO} =
    let pool = savepointPool("statement_not_aborted");
    let outcome = RawSql.runWithAllow(() -> DbError.runWithFailure(() -> Pool.withLazyTx(pool, () -> {
        insertRow("d");
        DbError.runWithFailure(() -> insertRow("d")) |> Result.isErr
    })));
    let seen = names(pool);
    Pool.close(pool);
    Assert.assertEq(expected = (Ok(true), Ok(List#{"d"})), (outcome, seen))
