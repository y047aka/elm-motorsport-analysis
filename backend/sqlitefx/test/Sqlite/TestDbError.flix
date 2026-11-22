use Sqlitefx.DbErr
use Sqlitefx.DbError
use Sqlitefx.DbWrite
use Sqlitefx.Jdbc
use Sqlitefx.RawSql
use Sqlitefx.Sql
use Sqlitefx.Tx
use Sqlitefx.{SqlRead, SqlWrite, SqlSavepoint, TransientDbErr}

use Sqlitefx.DbError.DbErrorKind
use Sqlitefx.DbError.Failure
use Sqlitefx.DbError.TransientKind

import java.io.File

// DbError: 実 SQLite が返す失敗が、どの kind に翻訳されるか。

/// kind を比べやすい形にする。違反した物はそのまま、メッセージを持つ物は種類だけ。
def shapeOf(failure: Failure): String = match failure {
    case Failure.Transient(TransientKind.ConnectionLost(_)) => "transient connectionLost"
    case Failure.Transient(transient)                       => "transient ${DbError.describeTransient(transient)}"
    case Failure.Permanent(DbErrorKind.SchemaMismatch(_))   => "schemaMismatch"
    case Failure.Permanent(DbErrorKind.Other(_))            => "other"
    case Failure.Permanent(kind)                            => DbError.describe(kind)
}

/// ロックを取り合うので、メモリ上でなくファイルの DB。
///
/// WhyNot: shared-cache のメモリ上の DB にしないのは、そこでは表の単位のロックになり、`busy_timeout` を待たずにLOCKED が返って、ファイルの DB で起きる BUSY の道を通らないから。
def kindsDb(): Jdbc.ConnectionConfig \ IO =
    let file = File.createTempFile("sqlitefx-kinds", ".db");
    file.deleteOnExit();
    Jdbc.config("jdbc:sqlite:${file.getPath()}")

/// 分類用の表を作り直す。
def resetKindTables(): Unit \ DbWrite + RawSql =
    discard Sql.execute(
        "CREATE TABLE sqlitefx_test_kinds (id INTEGER PRIMARY KEY, name TEXT NOT NULL, email TEXT UNIQUE, "
            + "CONSTRAINT sqlitefx_test_kinds_name_len CHECK (length(name) >= 2))", Nil);
    discard Sql.execute("CREATE TABLE sqlitefx_test_kind_posts (id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES sqlitefx_test_kinds (id))", Nil);
    discard Sql.execute("INSERT INTO sqlitefx_test_kinds (name, email) VALUES ('alice', 'a@example.com')", Nil)

/// 新しい接続で body を走らせ、失敗の形を返す。
def failureOn(config: Jdbc.ConnectionConfig, body: Unit -> Unit \ ef): Result[String, Unit] \ (ef - {SqlRead, SqlWrite, SqlSavepoint, TransientDbErr, DbErr, RawSql}) + IO =
    RawSql.runWithAllow(() -> DbError.runWithFailure(() -> Jdbc.withConnection(config, _ -> body()))) |> Result.mapErr(shapeOf)

/// 別の接続が書き込みのロックを持っている間に、`busy_timeout` 100 ms で書く。
def busyCase(config: Jdbc.ConnectionConfig): Result[String, Unit] \ IO =
    let impatient = { pragmas = List#{"busy_timeout = 100"} | config };
    RawSql.runWithAllow(() -> DbError.runWithFailure(() -> Jdbc.withConnection(config, holder ->
        Tx.withTx(holder, () -> {
            discard Sql.execute("UPDATE sqlitefx_test_kinds SET email = 'held@example.com' WHERE name = 'alice'", Nil);
            failureOn(impatient, () -> discard Sql.execute("UPDATE sqlitefx_test_kinds SET email = 'b@example.com' WHERE name = 'alice'", Nil))
        }))))
        |> Result.mapErr(shapeOf)
        |> Result.flatMap(inner -> inner)

/// 閉じた接続で SQL を出す。
def closedConnectionCase(config: Jdbc.ConnectionConfig): Result[String, Unit] \ IO =
    RawSql.runWithAllow(() -> DbError.runWithFailure(() -> {
        let conn = Jdbc.connect(config);
        Jdbc.close(conn);
        Jdbc.runWithConnection(conn, () -> discard Sql.fetch("SELECT 1", Nil))
    })) |> Result.mapErr(shapeOf)

/// SQLite が返す result code ごとの kind。isTransient に乗る物（transient …）は再試行される。
///
///   UNIQUE 違反                         → uniqueViolation sqlitefx_test_kinds.email
///   外部キー違反                         → foreignKeyViolation（SQLite は何も名指さない）
///   名前付きの CHECK 違反                → checkViolation sqlitefx_test_kinds_name_len
///   NOT NULL 違反                        → notNullViolation sqlitefx_test_kinds.name
///   他の接続の書き込みのロック（BUSY）     → transient timeout 0（busy_timeout を待った上限。再試行で通りうる）
///   表が無い                             → schemaMismatch
///   構文の誤り                           → other
///   閉じた接続                           → other（同じ接続で送り直しても通らない）
///
/// WhyNot: PG の版にある 0 除算・statement_timeout・直列化失敗・backend の停止を並べないのは、SQLite では0 除算が NULL で失敗せず、文の時間切れと直列化失敗に当たる物が無く、止める backend が無いから。
@Test
def testErrorKindTable(): Unit \ {Assert, IO} =
    let config = kindsDb();
    discard failureOn(config, resetKindTables);
    let seen = List#{
        failureOn(config, () -> discard Sql.execute("INSERT INTO sqlitefx_test_kinds (name, email) VALUES ('bob', 'a@example.com')", Nil)),
        failureOn(config, () -> discard Sql.execute("INSERT INTO sqlitefx_test_kind_posts (user_id) VALUES (999999)", Nil)),
        failureOn(config, () -> discard Sql.execute("INSERT INTO sqlitefx_test_kinds (name) VALUES ('x')", Nil)),
        failureOn(config, () -> discard Sql.execute("INSERT INTO sqlitefx_test_kinds (name) VALUES (NULL)", Nil)),
        busyCase(config),
        failureOn(config, () -> discard Sql.fetch("SELECT * FROM sqlitefx_no_such_table", Nil)),
        failureOn(config, () -> discard Sql.fetch("SELCT 1", Nil)),
        closedConnectionCase(config)
    };
    Assert.assertEq(
        expected = List#{
            Err("uniqueViolation sqlitefx_test_kinds.email"),
            Err("foreignKeyViolation FOREIGN KEY constraint failed"),
            Err("checkViolation sqlitefx_test_kinds_name_len"),
            Err("notNullViolation sqlitefx_test_kinds.name"),
            Err("transient timeout 0"),
            Err("schemaMismatch"),
            Err("other"),
            Err("other")
        },
        seen)
