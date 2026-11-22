import java.lang.System

use Sqlitefx.DbErr
use Sqlitefx.DbError
use Sqlitefx.Decoder
use Sqlitefx.Jdbc
use Sqlitefx.Migrate
use Sqlitefx.RawSql
use Sqlitefx.Sql
use Sqlitefx.SqlValue
use Sqlitefx.TransientDbErr
use Sqlitefx.{SqlRead, SqlWrite, SqlSavepoint}

use Sqlitefx.SqlValue.SqlValue
use Sqlitefx.DbError.Failure
use Sqlitefx.Migrate.Status

// Migrate: 実 SQLite で apply / status / check。fixtures は test/fixtures/migrations（3 ファイル。003 は no-transaction）。

def fixtures(): String = "test/fixtures/migrations"

/// テストごとの DB。`apply` は自分の接続を開いて閉じるので、閉じても DB が消えないように、テストの間 1 本開けておく。
def withMigrationDb(name: String, body: Jdbc.ConnectionConfig -> a \ ef): a \ ef + IO =
    let config = Jdbc.config("jdbc:sqlite:file:${name}?mode=memory&cache=shared");
    let keeper = DbError.runWithFailure(() -> Jdbc.connect(config));
    let result = body(config);
    match keeper { case Ok(conn) => Jdbc.close(conn) case Err(_) => () };
    result

def withSql(config: Jdbc.ConnectionConfig, body: Unit -> a \ ef): Result[Failure, a] \ (ef - {SqlRead, SqlWrite, SqlSavepoint, RawSql, DbErr, TransientDbErr}) + IO =
    DbError.runWithFailure(() -> RawSql.runWithAllow(() -> Jdbc.withConnection(config, _ -> body())))

def runMigrate(thunk: Unit -> a \ ef): Result[String, a] \ (ef - {Migrate.MigrateErr, TransientDbErr, DbErr, Fs.ReadFile.ReadFile, Fs.FileRead.FileRead, Fs.DirList.DirList}) + IO =
    let outcome = run {
        Migrate.runWithResult(() -> DbError.runWithFailure(thunk) |> Result.mapErr(DbError.describeFailure))
    } with Fs.ReadFile.runWithFileRead
      with Fs.FileRead.runWithIO
      with Fs.DirList.runWithIO;
    Result.flatMap(identity, outcome)

def appliedOrNot(status: Status): (String, Bool) = match status {
    case Status.Applied(version, _, _) => (version, true)
    case Status.Pending(version) => (version, false)
}

/// apply は未適用を番号順に当て、2 回目は何も当てない。当てた後は status が全部 Applied で、check が通る。
/// 001 は CREATE と INSERT の 2 文で、INSERT の行がある = 1 つの Statement に渡した複数文が全部当たっている。
///
///   001 create + insert / 002 add column / 003 index + VACUUM (no-transaction)
@Test
def testMigrateApplyThenNoop(): Unit \ {Assert, IO} =
    let observed = withMigrationDb("migrate_apply", config -> {
        let first = runMigrate(() -> Migrate.apply(Migrate.defaultConfig(config), fixtures()));
        let second = runMigrate(() -> Migrate.apply(Migrate.defaultConfig(config), fixtures()));
        let statuses = runMigrate(() -> Jdbc.withConnection(config, conn -> Migrate.status(conn, fixtures()))) |> Result.map(List.map(appliedOrNot));
        let checked = runMigrate(() -> Jdbc.withConnection(config, conn -> Migrate.check(conn, fixtures())));
        let rows = withSql(config, () -> Sql.fetchAs(Decoder.opt(Decoder.str("note")), "SELECT note FROM sqlitefx_mig_test", Nil));
        (first, second, statuses, checked, rows)
    });
    Assert.assertEq(
        expected = (Ok(List#{"001_create.sql", "002_add_note.sql", "003_index.sql"}), Ok(Nil),
                    Ok(List#{("001_create.sql", true), ("002_add_note.sql", true), ("003_index.sql", true)}), Ok(()), Ok(List#{None})),
        observed)

/// 当てる前の check は pending、適用済みの記録の checksum を書き換えると checksumMismatch、ファイルに無い version を記録に足すと missingFile。どれも MigrateErr として型に出る。
@Test
def testMigrateCheckFailures(): Unit \ {Assert, IO} =
    let observed = withMigrationDb("migrate_check", config -> {
        let pendingBefore = runMigrate(() -> Jdbc.withConnection(config, conn -> Migrate.check(conn, fixtures())));
        let _ = runMigrate(() -> Migrate.apply(Migrate.defaultConfig(config), fixtures()));
        let _ = withSql(config, () -> Sql.execute("UPDATE sqlitefx_migrations SET checksum = 'tampered' WHERE version = '002_add_note.sql'", Nil));
        let mismatch = runMigrate(() -> Jdbc.withConnection(config, conn -> Migrate.check(conn, fixtures())));
        let _ = withSql(config, () -> Sql.execute("UPDATE sqlitefx_migrations SET checksum = $1 WHERE version = '002_add_note.sql'", List#{SqlValue.Str(Migrate.checksum("ALTER TABLE sqlitefx_mig_test ADD COLUMN note TEXT;\n"))}));
        let _ = withSql(config, () -> Sql.execute("INSERT INTO sqlitefx_migrations (version, checksum, applied_at, execution_ms) VALUES ('000_gone.sql', 'x', 0, 0)", Nil));
        let missing = runMigrate(() -> Jdbc.withConnection(config, conn -> Migrate.check(conn, fixtures())));
        (pendingBefore, mismatch, missing)
    });
    Assert.assertEq(
        expected = (Err("pending: 001_create.sql, 002_add_note.sql, 003_index.sql"), Err("checksum mismatch: 002_add_note.sql"), Err("missing file: 000_gone.sql")),
        observed)

/// 形式の違うファイル名があれば、何も当てずに invalidFileName。
@Test
def testMigrateRejectsBadFileName(): Unit \ {Assert, IO} =
    let result = withMigrationDb("migrate_badname", config -> runMigrate(() -> Migrate.apply(Migrate.defaultConfig(config), "test/fixtures/bad_migrations")));
    Assert.assertEq(expected = Err("invalid file name: 1_short.sql (expected NNN_name.sql)"), result)

/// 同じ番号のファイルが 2 つあれば、何も当てずに duplicateNumber。
@Test
def testMigrateRejectsDuplicateNumber(): Unit \ {Assert, IO} =
    let result = withMigrationDb("migrate_dup", config -> runMigrate(() -> Migrate.apply(Migrate.defaultConfig(config), "test/fixtures/dup_migrations")));
    Assert.assertEq(expected = Err("duplicate number: 002_a.sql, 002_b.sql"), result)

/// 途中のファイルが失敗すると、そのファイルは記録されず後続も当たらない。前のファイルは残る。
///
///   001 OK / 002 を壊す（存在しない表への ALTER）→ 002 と 003 は未適用のまま
@Test
def testMigrateStopsAtFirstFailure(): Unit \ {Assert, IO} =
    let broken = "test/fixtures/broken_migrations";
    let observed = withMigrationDb("migrate_broken", config -> {
        let outcome = runMigrate(() -> Migrate.apply(Migrate.defaultConfig(config), broken))
            |> Result.mapErr(message -> String.startsWith(prefix = "schemaMismatch", message));
        let statuses = runMigrate(() -> Jdbc.withConnection(config, conn -> Migrate.status(conn, broken))) |> Result.map(List.map(appliedOrNot));
        (outcome, statuses)
    });
    Assert.assertEq(
        expected = (Err(true), Ok(List#{("001_create.sql", true), ("002_broken.sql", false), ("003_never.sql", false)})),
        observed)

/// 記録の時刻は apply の時刻（epoch マイクロ秒）で、Decoder.timestamp で読める。
@Test
def testMigrateRecordsWhenItApplied(): Unit \ {Assert, IO} =
    let before = System.currentTimeMillis() * 1000i64;
    let observed = withMigrationDb("migrate_time", config -> {
        let _ = runMigrate(() -> Migrate.apply(Migrate.defaultConfig(config), fixtures()));
        withSql(config, () -> Sql.fetchAs(Decoder.int64("applied_at"), "SELECT applied_at FROM sqlitefx_migrations", Nil))
    });
    let after = System.currentTimeMillis() * 1000i64;
    Assert.assertEq(expected = Ok(true), observed |> Result.map(times -> List.length(times) == 3 and List.forAll(t -> t >= before and t <= after, times)))
