use Sqlitefx.Date
use Sqlitefx.Db
use Sqlitefx.DbError
use Sqlitefx.DbErr
use Sqlitefx.DbWrite
use Sqlitefx.Decoder
use Sqlitefx.Jdbc
use Sqlitefx.RawSql
use Sqlitefx.Row
use Sqlitefx.Sql
use Sqlitefx.SqlValue
use Sqlitefx.Timestamp
use Sqlitefx.Tx
use Sqlitefx.Uuid
use Sqlitefx.{SqlRead, SqlWrite, SqlSavepoint, TransientDbErr}

use Sqlitefx.SqlValue.SqlValue
use Sqlitefx.DbError.DbErrorKind
use Sqlitefx.DbError.Failure

// Jdbc: 実 SQLite（sqlite-jdbc のメモリ上の DB）に当たるテスト。サーバは要らない。

/// テストごとの DB。`cache=shared` なので、同じ名前の接続どうしは同じ DB を見る（最後の接続が閉じると消える）。
///
/// WhyNot: `jdbc:sqlite::memory:` にしないのは、それが接続ごとに別の DB で、「別の接続から見えるか」を確かめられないから。
/// 名前をテストごとに分けるのは、テストが並んで走ると同じ名前の DB を取り合うから。
def memoryDb(name: String): Jdbc.ConnectionConfig =
    Jdbc.config("jdbc:sqlite:file:${name}?mode=memory&cache=shared")

/// 接続を開いて body を走らせ、必ず閉じる。失敗は Failure に落とす。
def withDb(name: String, body: Unit -> a \ ef): Result[Failure, a] \ (ef - {SqlRead, SqlWrite, SqlSavepoint, RawSql, DbErr, TransientDbErr}) + IO =
    DbError.runWithFailure(() -> RawSql.runWithAllow(() -> Jdbc.withConnection(memoryDb(name), _ -> body())))

/// テーブルを作り直す。
def resetUsers(): Unit \ DbWrite + RawSql =
    let _ = Sql.execute("DROP TABLE IF EXISTS sqlitefx_test_users", Nil);
    let _ = Sql.execute(
        "CREATE TABLE sqlitefx_test_users (id INTEGER PRIMARY KEY, name TEXT NOT NULL, email TEXT UNIQUE, "
            + "score TEXT, active INTEGER NOT NULL DEFAULT 1, created_at INTEGER NOT NULL)", Nil);
    ()

// ---- 記憶クラス ----

/// 送った SqlValue が、どの記憶クラスで返るか（JdbcConvert の表）。列に型を宣言しないので、SQLite は送った物をそのまま持つ。
///
///   Bool(true) → Int32(1)          Int64(5000000000) → Int64        Decimal(12.50) → Str("12.50")
///   Timestamp(-1500000) → Int32    Date(20702) → Int32              Uuid / Json → Str
///   Int64Array / StrArray / Int32Array / JsonArray → JSON の配列の Str
@Test
def testStorageClasses(): Unit \ {Assert, IO} =
    let sent = List#{
        SqlValue.Bool(true), SqlValue.Int32(7), SqlValue.Int64(5000000000i64), SqlValue.Float64(1.5), SqlValue.Decimal(12.50ff),
        SqlValue.Str("s"), SqlValue.Bytes(Vector#{1i8, -2i8}), SqlValue.Timestamp(-1500000i64), SqlValue.Date(20702),
        SqlValue.Uuid("550e8400-e29b-41d4-a716-446655440000"), SqlValue.Json("{\"k\":1}"),
        SqlValue.Int64Array(List#{1i64, 2i64}), SqlValue.StrArray(List#{"a", "b\""}), SqlValue.Int32Array(List#{7, -3}),
        SqlValue.JsonArray(List#{"{\"a\":1}", "[1,2]"})
    };
    let result = withDb("storage", () -> {
        discard Sql.execute("CREATE TABLE t (c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15)", Nil);
        discard Sql.execute("INSERT INTO t VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)", sent);
        Sql.fetchOne("SELECT * FROM t", Nil) |> Option.map(row -> row#cells |> Vector.toList)
    });
    Assert.assertEq(expected = Ok(Some(List#{
        SqlValue.Int32(1), SqlValue.Int32(7), SqlValue.Int64(5000000000i64), SqlValue.Float64(1.5), SqlValue.Str("12.50"),
        SqlValue.Str("s"), SqlValue.Bytes(Vector#{1i8, -2i8}), SqlValue.Int32(-1500000), SqlValue.Int32(20702),
        SqlValue.Str("550e8400-e29b-41d4-a716-446655440000"), SqlValue.Str("{\"k\":1}"),
        SqlValue.Str("[1,2]"), SqlValue.Str("[\"a\",\"b\\\"\"]"), SqlValue.Str("[7,-3]"),
        SqlValue.Str("[{\"a\":1},[1,2]]")
    })), result)

/// 意味を持つ型を、宣言のある列と往復する。書くときは SqlValue.ofTimestamp 等で包み、読むときは Decoder で意味を持つ型に戻る。
///
///   Timestamp '2026-09-06T01:00:00.123456Z' / Date '2026-09-06' / Uuid / Json '{"n": 1}' / Bool / Decimal 12.50 → 同じ値で返る
@Test
def testSemanticTypesRoundTrip(): Unit \ {Assert, IO} =
    let at = Timestamp.at("2026-09-06T01:00:00.123456Z");
    let day = Date.at("2026-09-06");
    let key = Uuid.fromString("550e8400-e29b-41d4-a716-446655440000") |> Option.getWithDefault(Uuid.Uuid(""));
    let meta = Util.Json.Json.JObject(Map#{"n" => Util.Json.Json.JNumber(1ff)});
    let decoder = forA (
        t <- Decoder.timestamp("t");
        d <- Decoder.date("d");
        u <- Decoder.uuid("u");
        j <- Decoder.jsonAs("j");
        b <- Decoder.bool("b");
        m <- Decoder.decimal("m")
    ) yield (t, d, u, (j: Map[String, Int32]), b, m);
    let result = withDb("semantic", () -> {
        discard Sql.execute("CREATE TABLE t (t INTEGER, d INTEGER, u TEXT, j TEXT, b INTEGER, m TEXT)", Nil);
        discard Sql.execute("INSERT INTO t VALUES ($1, $2, $3, $4, $5, $6)",
            List#{SqlValue.ofTimestamp(at), SqlValue.ofDate(day), SqlValue.ofUuid(key), SqlValue.ofJson(meta), SqlValue.Bool(false), SqlValue.Decimal(12.50ff)});
        Sql.fetchOneAs(decoder, "SELECT t, d, u, j, b, m FROM t", Nil)
    });
    Assert.assertEq(expected = Ok(Some((at, day, key, Map#{"n" => 1}, false, 12.50ff))), result)

/// 配列は JSON の TEXT で送るので、`json_each($1)` で行に開けて、PG の `= ANY($1)` の代わりに使える。
/// 列に入れた配列は Decoder で List に戻る。
///
///   json_each([7, -3]) → 7, -3      WHERE id IN (json_each([1, 3])) → a, c
@Test
def testArraysThroughJsonEach(): Unit \ {Assert, IO} =
    let result = withDb("arrays", () -> {
        resetUsers();
        discard Sql.execute("INSERT INTO sqlitefx_test_users (id, name, created_at) VALUES (1, 'a', 0), (2, 'b', 0), (3, 'c', 0)", Nil);
        let opened = Sql.fetchAs(Decoder.int32("value"), "SELECT value FROM json_each($1)", List#{SqlValue.Int32Array(List#{7, -3})});
        let picked = Sql.fetchAs(Decoder.str("name"), "SELECT name FROM sqlitefx_test_users WHERE id IN (SELECT value FROM json_each($1)) ORDER BY id",
            List#{SqlValue.Int64Array(List#{1i64, 3i64})});
        discard Sql.execute("CREATE TABLE t (tags TEXT, ns TEXT)", Nil);
        discard Sql.execute("INSERT INTO t VALUES ($1, $2)", List#{SqlValue.StrArray(List#{"x", "y"}), SqlValue.Int64Array(List#{5i64})});
        let read = Sql.fetchOneAs(forA (tags <- Decoder.strArray("tags"); ns <- Decoder.int64Array("ns")) yield (tags, ns), "SELECT tags, ns FROM t", Nil);
        (opened, picked, read)
    });
    Assert.assertEq(expected = Ok((List#{7, -3}, List#{"a", "c"}, Some((List#{"x", "y"}, List#{5i64})))), result)

// ---- INSERT → SELECT ----

/// INTEGER PRIMARY KEY は rowid なので 1 から振られる。影響行数は execute の戻り、0 行は None。
@Test
def testIdAndAffected(): Unit \ {Assert, IO} =
    let result = withDb("ids", () -> {
        resetUsers();
        let inserted = Sql.execute("INSERT INTO sqlitefx_test_users (name, created_at) VALUES ($1, 0), ($2, 0)", List#{SqlValue.Str("a"), SqlValue.Str("b")});
        let ids = Sql.fetchAs(Decoder.int64("id"), "SELECT id FROM sqlitefx_test_users ORDER BY id", Nil);
        let missing = Sql.fetchOne("SELECT id FROM sqlitefx_test_users WHERE id = $1", List#{SqlValue.Int64(999i64)});
        (inserted, ids, Option.isEmpty(missing))
    });
    Assert.assertEq(expected = Ok((2, List#{1i64, 2i64}, true)), result)

/// `RETURNING` の行が executeReturning で返る。
@Test
def testExecuteReturning(): Unit \ {Assert, IO} =
    let result = withDb("returning", () -> {
        resetUsers();
        Sql.executeReturningAs(Decoder.int64("id"), "INSERT INTO sqlitefx_test_users (name, created_at) VALUES ('a', 0), ('b', 0) RETURNING id", Nil)
    });
    Assert.assertEq(expected = Ok(List#{1i64, 2i64}), result)

/// 結合で両側の同じ名前の列を並べても、列名は結果セットの順に 2 回並ぶ（sqlite-jdbc はどちらも `id` と答える）。
@Test
def testJoinKeepsBothColumnNames(): Unit \ {Assert, IO} =
    let result = withDb("join_names", () -> {
        discard Sql.execute("CREATE TABLE a (id INTEGER)", Nil);
        discard Sql.execute("CREATE TABLE b (id INTEGER)", Nil);
        discard Sql.execute("INSERT INTO a VALUES (1)", Nil);
        discard Sql.execute("INSERT INTO b VALUES (2)", Nil);
        Sql.fetchOne("SELECT a.id, b.id FROM a, b", Nil) |> Option.map(row -> (Row.columnNames(row), row#cells |> Vector.toList))
    });
    Assert.assertEq(expected = Ok(Some((List#{"id", "id"}, List#{SqlValue.Int32(1), SqlValue.Int32(2)}))), result)

// ---- 例外の翻訳 ----

/// unique 違反は DbErr.uniqueViolation に、違反した `表.列` 付きで翻訳される。
@Test
def testUniqueViolation(): Unit \ {Assert, IO} =
    let result = withDb("unique", () -> {
        resetUsers();
        let _ = Sql.execute("INSERT INTO sqlitefx_test_users (name, email, created_at) VALUES ('a', 'x@example.com', 0)", Nil);
        let _ = Sql.execute("INSERT INTO sqlitefx_test_users (name, email, created_at) VALUES ('b', 'x@example.com', 0)", Nil);
        ()
    });
    Assert.assertEq(expected = Err(Failure.Permanent(DbErrorKind.UniqueViolation("sqlitefx_test_users.email"))), result)

/// 既定の pragma で外部キーが効く: 親の無い子は ForeignKeyViolation。
@Test
def testForeignKeysAreOnByDefault(): Unit \ {Assert, IO} =
    let result = withDb("fk", () -> {
        discard Sql.execute("CREATE TABLE parent (id INTEGER PRIMARY KEY)", Nil);
        discard Sql.execute("CREATE TABLE child (parent_id INTEGER NOT NULL REFERENCES parent (id))", Nil);
        discard Sql.execute("INSERT INTO child VALUES (1)", Nil)
    });
    Assert.assertEq(expected = Err(Failure.Permanent(DbErrorKind.ForeignKeyViolation("FOREIGN KEY constraint failed"))), result)

/// 無いテーブルは DbErr.schemaMismatch。
@Test
def testMissingTableIsSchemaMismatch(): Unit \ {Assert, IO} =
    let result = withDb("missing", () -> Sql.fetch("SELECT 1 FROM sqlitefx_no_such_table", Nil) |> List.length)
        |> Result.mapErr(failure -> String.startsWith(prefix = "schemaMismatch", DbError.describeFailure(failure)));
    Assert.assertEq(expected = Err(true), result)

/// 断られた文が SchemaMismatch に載る: SQLite は解決できなかった列を言うだけなので、どの文だったかはこちらが足す。
/// 制約違反には載せない（違反した列を自分で名指す）。
@Test
def testRefusalCarriesTheStatement(): Unit \ {Assert, IO} =
    let missing = withDb("refusal", () -> Sql.fetch("SELECT nope FROM sqlitefx_test_users", Nil) |> List.length);
    let violated = withDb("refusal_unique", () -> {
        resetUsers();
        discard Sql.execute("INSERT INTO sqlitefx_test_users (id, name, created_at) VALUES (1, 'a', 0), (1, 'b', 0)", Nil)
    });
    let missingNamesStatement = match missing {
        case Err(Failure.Permanent(DbErrorKind.SchemaMismatch(detail))) => String.endsWith(suffix = ": SELECT nope FROM sqlitefx_test_users", detail)
        case _ => false
    };
    Assert.assertEq(expected = (true, Err(Failure.Permanent(DbErrorKind.UniqueViolation("sqlitefx_test_users.id")))), (missingNamesStatement, violated))

/// 開けないファイル（`/dev/null` の下には作れない）は Transient の connectionLost。
@Test
def testUnopenableFileIsConnectionLost(): Unit \ {Assert, IO} =
    let result = DbError.runWithFailure(() -> RawSql.runWithAllow(() ->
        Jdbc.withConnection(Jdbc.config("jdbc:sqlite:/dev/null/none.db"), _ -> Sql.fetch("SELECT 1", Nil) |> List.length)));
    let transient = match result {
        case Err(Failure.Transient(DbError.TransientKind.ConnectionLost(_))) => true
        case _ => false
    };
    Assert.assertEq(expected = true, transient)

/// ExampleUsers のユースケースが、テーブル名を合わせれば実 SQLite でもそのまま動く形であることの確認。
@Test
def testListUsersShape(): Unit \ {Assert, IO} =
    let result = withDb("example", () -> {
        resetUsers();
        let _ = Sql.execute("INSERT INTO sqlitefx_test_users (name, email, created_at) VALUES ('bob', NULL, 0), ('alice', 'a@example.com', 0)", Nil);
        Sql.fetchAs(ExampleUsers.userDecoder(), "SELECT id, name, email FROM sqlitefx_test_users ORDER BY name", Nil)
            |> List.map(user -> (user#name, user#email))
    });
    Assert.assertEq(expected = Ok(List#{("alice", Some("a@example.com")), ("bob", None)}), result)

/// Decoder の型不一致は DbErr.decodeError になる（TEXT の列を Int32 で読む）。
@Test
def testDecodeErrorIsDbErr(): Unit \ {Assert, IO} =
    let result = withDb("decode", () -> {
        resetUsers();
        discard Sql.execute("INSERT INTO sqlitefx_test_users (name, created_at) VALUES ('a', 0)", Nil);
        Sql.fetchAs(Decoder.int32("name"), "SELECT name FROM sqlitefx_test_users", Nil)
    });
    Assert.assertEq(expected = Err(Failure.Permanent(DbErrorKind.DecodeError("name", "column 'name' is Str, expected Int32"))), result)

// ---- withTx ----

/// withTx は DbErr で ROLLBACK する: unique 違反の前に入れた行が残らない。
///
///   BEGIN
///     INSERT a        ← これは ROLLBACK で消える
///     INSERT a (重複) ← uniqueViolation
///   ROLLBACK
@Test
def testTxRollsBackOnDbErr(): Unit \ {Assert, IO} =
    let result = RawSql.runWithAllow(() -> DbError.runWithFailure(() -> {
        let conn = Jdbc.connect(memoryDb("rollback"));
        let _ = Jdbc.runWithConnection(conn, resetUsers);
        let failed = DbError.runWithFailure(() -> Tx.withTx(conn, () -> {
            let _ = Sql.execute("INSERT INTO sqlitefx_test_users (name, email, created_at) VALUES ('a', 'x@example.com', 0)", Nil);
            let _ = Sql.execute("INSERT INTO sqlitefx_test_users (name, email, created_at) VALUES ('b', 'x@example.com', 0)", Nil);
            ()
        }));
        let remaining = Jdbc.runWithConnection(conn, () -> Sql.fetch("SELECT id FROM sqlitefx_test_users", Nil) |> List.length);
        Jdbc.close(conn);
        (failed, remaining)
    }));
    Assert.assertEq(expected = Ok((Err(Failure.Permanent(DbErrorKind.UniqueViolation("sqlitefx_test_users.email"))), 0)), result)

/// withTx は正常なら COMMIT する: 別接続から行が見える。
@Test
def testTxCommits(): Unit \ {Assert, IO} =
    let result = RawSql.runWithAllow(() -> DbError.runWithFailure(() -> {
        let config = memoryDb("commits");
        let conn = Jdbc.connect(config);
        let _ = Jdbc.runWithConnection(conn, resetUsers);
        Tx.withTx(conn, () -> {
            let _ = Sql.execute("INSERT INTO sqlitefx_test_users (name, created_at) VALUES ('a', 0)", Nil);
            ()
        });
        let other = Jdbc.connect(config);
        let seen = Jdbc.runWithConnection(other, () -> Sql.fetch("SELECT id FROM sqlitefx_test_users", Nil) |> List.length);
        Jdbc.close(other);
        Jdbc.close(conn);
        seen
    }));
    Assert.assertEq(expected = Ok(1), result)

// ---- NULL ----

/// 宣言のある列が全部 NULL の行を読める。
@Test
def testAllNullRow(): Unit \ {Assert, IO} =
    let result = withDb("nulls", () -> {
        discard Sql.execute("CREATE TABLE t (d TEXT, t INTEGER, b BLOB, f REAL, i INTEGER)", Nil);
        discard Sql.execute("INSERT INTO t DEFAULT VALUES", Nil);
        Sql.fetchOne("SELECT * FROM t", Nil) |> Option.map(row -> row#cells |> Vector.toList)
    });
    Assert.assertEq(expected = Ok(Some(List.repeat(5, SqlValue.Null))), result)

/// 型の付いた NULL（NullOf）は全部の型を送れて、列に NULL が入る。
@Test
def testTypedNullsBind(): Unit \ {Assert, IO} =
    let typedNulls = List#{
        SqlValue.NullOf(SqlValue.NullType.Bool), SqlValue.NullOf(SqlValue.NullType.Int32), SqlValue.NullOf(SqlValue.NullType.Int64),
        SqlValue.NullOf(SqlValue.NullType.Float64), SqlValue.NullOf(SqlValue.NullType.Decimal), SqlValue.NullOf(SqlValue.NullType.Str),
        SqlValue.NullOf(SqlValue.NullType.Bytes), SqlValue.NullOf(SqlValue.NullType.Timestamp), SqlValue.NullOf(SqlValue.NullType.Date),
        SqlValue.NullOf(SqlValue.NullType.Uuid), SqlValue.NullOf(SqlValue.NullType.Json), SqlValue.NullOf(SqlValue.NullType.Int64Array),
        SqlValue.NullOf(SqlValue.NullType.StrArray), SqlValue.NullOf(SqlValue.NullType.Int32Array), SqlValue.NullOf(SqlValue.NullType.JsonArray)
    };
    let result = withDb("typednulls", () -> {
        discard Sql.execute("CREATE TABLE t (c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15)", Nil);
        discard Sql.execute("INSERT INTO t VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)", typedNulls);
        Sql.fetchOne("SELECT * FROM t", Nil) |> Option.map(row -> row#cells |> Vector.toList)
    });
    Assert.assertEq(expected = Ok(Some(List.repeat(15, SqlValue.Null))), result)

/// 型の付いた NULL は `col = $1` では何も引かず（SQL の `= NULL` の意味）、`col IS $1` では NULL の行を引く。
@Test
def testTypedNullInComparison(): Unit \ {Assert, IO} =
    let result = withDb("nullcompare", () -> {
        resetUsers();
        discard Sql.execute("INSERT INTO sqlitefx_test_users (name, email, created_at) VALUES ('a', NULL, 0)", Nil);
        let byEquality = Sql.fetch("SELECT id FROM sqlitefx_test_users WHERE email = $1", List#{SqlValue.NullOf(SqlValue.NullType.Str)}) |> List.length;
        let byIs = Sql.fetch("SELECT id FROM sqlitefx_test_users WHERE email IS $1", List#{SqlValue.NullOf(SqlValue.NullType.Str)}) |> List.length;
        (byEquality, byIs)
    });
    Assert.assertEq(expected = Ok((0, 1)), result)

// ---- withConnection / COMMIT の失敗 ----

/// withConnection は失敗しても接続を閉じ、エラーはそのまま上がる。
@Test
def testWithConnectionClosesOnError(): Unit \ {Assert, IO} =
    let result = withDb("closes", () -> Sql.fetch("SELECT 1 FROM sqlitefx_no_such_table", Nil))
        |> Result.mapErr(failure -> String.startsWith(prefix = "schemaMismatch", DbError.describeFailure(failure)))
        |> Result.map(List.length);
    Assert.assertEq(expected = Err(true), result)

/// COMMIT で初めて出るエラー（DEFERRABLE な外部キー）も DbErr に翻訳され、接続は autocommit に戻っている。
///
///   BEGIN → INSERT 親の無い子（遅延なのでここでは通る）→ COMMIT ← ここで FOREIGN KEY constraint failed
///   その後の INSERT が別の接続から見える = autocommit に戻っている
///
/// WhyNot: PG の版のように遅延 UNIQUE で起こさないのは、SQLite で遅延できる制約が外部キーだけだから。
@Test
def testCommitFailureIsTranslated(): Unit \ {Assert, IO} =
    let config = memoryDb("commitfailure");
    let result = RawSql.runWithAllow(() -> DbError.runWithFailure(() -> Jdbc.withConnection(config, conn -> {
        discard Sql.execute("CREATE TABLE parent (id INTEGER PRIMARY KEY)", Nil);
        discard Sql.execute("CREATE TABLE child (parent_id INTEGER NOT NULL REFERENCES parent (id) DEFERRABLE INITIALLY DEFERRED)", Nil);
        let failed = DbError.runWithFailure(() -> Tx.withTx(conn, () -> {
            discard Sql.execute("INSERT INTO child VALUES (1)", Nil)
        }));
        discard Sql.execute("INSERT INTO parent VALUES (1)", Nil);
        let seen = Jdbc.withConnection(config, _ -> Sql.fetch("SELECT id FROM parent", Nil) |> List.length);
        (failed, seen)
    })));
    Assert.assertEq(expected = Ok((Err(Failure.Permanent(DbErrorKind.ForeignKeyViolation("FOREIGN KEY constraint failed"))), 1)), result)
