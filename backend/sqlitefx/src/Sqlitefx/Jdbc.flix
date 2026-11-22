///
/// JDBC ハンドラ。SqlRead / SqlWrite を java.sql に落とし、SQLException を 3 分類に翻訳する。
///
pub mod Sqlitefx.Jdbc {

    use Sqlitefx.Db
    use Sqlitefx.DbErr
    use Sqlitefx.DbError
    use Sqlitefx.JdbcConvert
    use Sqlitefx.Row
    use Sqlitefx.Savepoint
    use Sqlitefx.SqlRead
    use Sqlitefx.SqlSavepoint
    use Sqlitefx.SqlState
    use Sqlitefx.SqlValue
    use Sqlitefx.SqlWrite
    use Sqlitefx.TransientDbErr

    import java.io.File
    import java.sql.Connection
    import java.sql.PreparedStatement
    import java.sql.ResultSet
    import java.sql.SQLException
    import java.sql.Statement
    import java.util.Properties
    import org.sqlite.JDBC

    use Sqlitefx.SqlValue.SqlValue
    use Sqlitefx.Row.Row

    ///
    /// 接続の設定。
    ///
    /// - `url`: `jdbc:sqlite:path/to/file.db`、メモリ上なら `jdbc:sqlite::memory:`
    /// - `pragmas`: 開いた直後、最初の Tx より前に 1 つずつ送る `PRAGMA` の中身（`journal_mode = WAL` など）
    ///
    /// WhyNot: user / password を持たないのは、SQLite が認証を持たず、ファイルに読み書きできるかが全てだから。
    ///
    pub type alias ConnectionConfig = { url = String, pragmas = List[String] }

    ///
    /// url に既定の pragma を付けた設定。
    ///
    pub def config(url: String): ConnectionConfig = { url = url, pragmas = defaultPragmas() }

    ///
    /// `foreign_keys = ON` と `busy_timeout = 5000`。
    ///
    /// WhyNot: `foreign_keys` を既定で入れるのは、SQLite は接続ごとに既定で外部キーを確かめず、`ForeignKeyViolation` が PG と同じ所で起きなくなるから。
    ///
    /// WhyNot: `busy_timeout` を既定で入れるのは、SQLite の既定が 0（他の接続が書いていれば待たずに BUSY）で、2 本目の接続がすぐ `Timeout` になるから。5 秒は待ってもらえるロックの長さの目安。
    ///
    /// WhyNot: `journal_mode = WAL` を既定にしないのは、ファイルに残る設定で、メモリ上の DB では効かず、読み手と書き手を並べたいかは利用側の都合だから。
    ///
    pub def defaultPragmas(): List[String] = List#{"foreign_keys = ON", "busy_timeout = 5000"}

    ///
    /// 1 本の接続を開き、pragma を送る。開けなければ TransientDbErr.connectionLost。
    ///
    /// WhyNot: `DriverManager.getConnection` を使わないのは、Flix の Maven クラスローダではドライバの自動登録が効かないから（docs/spikes.md (c)）。`JDBC` を直接 new する。
    ///
    /// WhyNot: ファイルの親ディレクトリを作るのは、SQLite はファイルを作ってもディレクトリは作らず、無いディレクトリを指す url が「開けない」になるから。
    ///
    pub def connect(config: ConnectionConfig): Connection \ {IO, TransientDbErr} =
        try {
            makeParentDirectory(config#url);
            let driver = new JDBC();
            let conn: Connection = driver.connect(config#url, new Properties());
            if (Object.isNull(conn))
                TransientDbErr.connectionLost("not a SQLite JDBC url: ${config#url}")
            else {
                sendPragmas(conn, config#pragmas);
                conn
            }
        } catch {
            case e: SQLException =>
                let msg: String = e.getMessage();
                TransientDbErr.connectionLost(msg)
        }

    ///
    /// pragma を 1 つずつ送る。Tx の外で呼ぶ（`journal_mode` は Tx の中では変えられない）。
    ///
    pub def sendPragmas(conn: Connection, pragmas: List[String]): Unit \ IO =
        List.forEach(pragma -> {
            let statement: Statement = conn.createStatement();
            discard statement.execute("PRAGMA ${pragma}");
            statement.close()
        }, pragmas)

    def makeParentDirectory(url: String): Unit \ IO =
        match String.stripPrefix(substr = "jdbc:sqlite:", url) {
            case Some(path) if not String.startsWith(prefix = ":", path) and not String.startsWith(prefix = "file:", path) =>
                match Object.toOption(new File(path).getParentFile()) {
                    case Some(parent) => discard parent.mkdirs()
                    case None         => ()
                }
            case _ => ()
        }

    ///
    /// 接続を閉じる。閉じるときの失敗は握りつぶす（もう使わない接続なので）。
    ///
    pub def close(conn: Connection): Unit \ IO =
        try {
            conn.close()
        } catch {
            case _: SQLException => ()
        }

    ///
    /// handler の本体と、handler の `run` 全体で JVM の例外を拾った時の扱い。Tx の入口（Pool / Tx / withConnection）が渡す。
    ///
    /// - `onFatal`: fatal を拾った時に、投げ直す前に呼ぶ（借りた接続の evict、自前の接続なら close）
    /// - `driverFailed`: fatal でない例外が sqlite-jdbc の中から出た時に true にする。接続の状態が分からないので、
    ///   受けた側は ROLLBACK を送らずに接続を捨てる
    ///
    pub type alias Watch = { onFatal = Unit -> Unit \ IO, driverFailed = Ref[Bool, Static] }

    ///
    /// fatal を拾っても何もしない（接続が呼び手の物で、捨てられない所）。
    ///
    pub def unwatched(): Watch \ IO = { onFatal = () -> checked_ecast(()), driverFailed = Ref.fresh(Static, false) }

    ///
    /// thunk を走らせ、JVM の例外を拾う。fatal は `onFatal` を呼んでから同じ物を投げ直す（値にしない）。
    /// fatal でない物は `DbErrorKind.Other` の値にし、sqlite-jdbc の中から出た物なら `driverFailed` を立てる。
    ///
    /// handler の本体（`resume` の前）と、handler の `run` 全体を外から包むのに使う。後者は、利用側の書き方で
    /// thunk の中の catch（`Db.guard`）を例外が飛ばした時に、op を受けた Pool の handler の所で拾う網。
    ///
    pub def watched(watch: Watch, thunk: Unit -> Result[DbError.DbErrorKind, a] \ ef): Result[DbError.DbErrorKind, a] \ ef + IO =
        match Db.catchAll(thunk) {
            case Ok(result) => result
            case Err(error) =>
                if (Db.isFatal(error)) {
                    (watch#onFatal)();
                    Db.rethrowing(Err(error))
                } else {
                    if (Db.fromDriver(error)) Ref.put(true, watch#driverFailed) else ();
                    Err(DbError.DbErrorKind.Other(Db.describeThrowable(error)))
                }
        }

    ///
    /// 1 本の接続で fetch / execute / SAVEPOINT の命令を実行する。結果は即時 materialize する。
    /// 失敗は値（DbErrorKind）で継続に渡し、呼び出し側の `Sql.*` / `Tx.withSavepoint` が op にする。継続は必ず 1 回呼ぶ。
    /// JDBC の中の fatal は投げ直す（接続は呼び手の物なので、捨てるのも呼び手）。
    ///
    pub def runWithConnection(conn: Connection, thunk: Unit -> a \ ef): a \ (ef - {SqlRead, SqlWrite, SqlSavepoint}) + IO =
        runWithConnectionWatched(() -> conn, unwatched(), thunk)

    ///
    /// `runWithConnection` の、接続を最初の SQL で取りに行く形。handler の本体の JDBC は `watched` で包み、
    /// `resume` は拾った後で呼ぶ（`resume` を try の中で呼ぶと、その先で thunk が投げた物を handler が拾ってしまう）。
    ///
    pub def runWithConnectionWatched(connect: Unit -> Connection \ ef2, watch: Watch, thunk: Unit -> a \ ef): a \ (ef - {SqlRead, SqlWrite, SqlSavepoint}) + (ef2 - {TransientDbErr, DbErr}) + IO =
        run {
            thunk()
        } with handler SqlRead {
            def fetch(sql, params, resume) = {
                let result = watched(watch, () -> DbError.runWithKind(() -> fetchRows(connect(), sql, params)));
                resume(result)
            }
        } with handler SqlWrite {
            def execute(sql, params, resume) = {
                let result = watched(watch, () -> DbError.runWithKind(() -> executeStatement(connect(), sql, params)));
                resume(result)
            }
            def executeReturning(sql, params, resume) = {
                let result = watched(watch, () -> DbError.runWithKind(() -> fetchRows(connect(), sql, params)));
                resume(result)
            }
        } with handler SqlSavepoint {
            def control(command, resume) = {
                let result = watched(watch, () -> DbError.runWithKind(() -> controlSavepoint(connect(), command)));
                resume(result)
            }
        }

    ///
    /// 接続を開いて thunk を走らせ、成功でも失敗でも必ず閉じる。失敗はそのまま再送出する。
    /// 「開く → runWithConnection → 閉じる」を毎回書かないための入口。Tx が要るなら thunk の中で `Tx.withTx` を呼ぶ。
    /// thunk の JVM の例外は `DbErr` の `Other`。fatal は接続を閉じてから投げ直す。sqlite-jdbc の中から出た例外の後も閉じる。
    ///
    pub def withConnection(config: ConnectionConfig, thunk: Connection -> a \ ef): a \ (ef - {SqlRead, SqlWrite, SqlSavepoint}) + {IO, TransientDbErr, DbErr} =
        let conn = connect(config);
        let watch = { onFatal = () -> close(conn), driverFailed = Ref.fresh(Static, false) };
        let outcome = watched(watch, () -> DbError.runWithKind(() -> runWithConnectionWatched(() -> conn, watch, () -> Db.guard(() -> thunk(conn)))));
        close(conn);
        match outcome {
            case Ok(value) => value
            case Err(kind) => DbError.raise(kind)
        }

    ///
    /// SELECT を発行して全行読む。
    ///
    pub def fetchRows(conn: Connection, sql: String, params: List[SqlValue]): List[Row] \ {IO, TransientDbErr, DbErr} =
        let (jdbcSql, ordered) = rewriteOrFail(sql, params);
        let statement = prepare(conn, sql, jdbcSql);
        try {
            JdbcConvert.bindParams(statement, ordered);
            let resultSet: ResultSet = statement.executeQuery();
            let rows = JdbcConvert.materialize(resultSet);
            resultSet.close();
            statement.close();
            rows
        } catch {
            case e: SQLException => { closeQuietly(statement); raiseRefusal(sql, e) }
        }

    ///
    /// INSERT / UPDATE / DELETE を発行して影響行数を返す。
    ///
    pub def executeStatement(conn: Connection, sql: String, params: List[SqlValue]): Int32 \ {IO, TransientDbErr, DbErr} =
        let (jdbcSql, ordered) = rewriteOrFail(sql, params);
        let statement = prepare(conn, sql, jdbcSql);
        try {
            JdbcConvert.bindParams(statement, ordered);
            let affected: Int32 = statement.executeUpdate();
            statement.close();
            affected
        } catch {
            case e: SQLException => { closeQuietly(statement); raiseRefusal(sql, e) }
        }

    ///
    /// SAVEPOINT / RELEASE / ROLLBACK TO を 1 つ発行する。名前は `Savepoint.isValidName` を通った物だけが来る。
    ///
    pub def controlSavepoint(conn: Connection, command: Savepoint.Command): Unit \ {IO, TransientDbErr, DbErr} =
        discard executeStatement(conn, Savepoint.toSql(command), Nil)

    ///
    /// PreparedStatement を作る。ここで失敗したら閉じる物は無い。
    ///
    def prepare(conn: Connection, sql: String, jdbcSql: String): PreparedStatement \ {IO, TransientDbErr, DbErr} =
        try {
            conn.prepareStatement(jdbcSql)
        } catch {
            case e: SQLException => raiseRefusal(sql, e)
        }

    ///
    /// 失敗した文を閉じる。閉じるときの失敗は元のエラーを優先して握りつぶす。
    ///
    def closeQuietly(statement: PreparedStatement): Unit \ IO =
        try {
            statement.close()
        } catch {
            case _: SQLException => ()
        }

    ///
    /// `$n` を `?` に書き換える。params に無い `$n` を参照していたら DbErr.other（SQL の書き間違い）。
    ///
    def rewriteOrFail(sql: String, params: List[SqlValue]): (String, List[SqlValue]) \ DbErr =
        match JdbcConvert.rewritePlaceholders(sql, params) {
            case Some(rewritten) => rewritten
            case None => DbErr.other("placeholders do not match ${List.length(params)} params ($n out of range, $n mixed with ?, or a ? count that differs): ${sql}")
        }

    ///
    /// SQLException を result code で翻訳して投げる。翻訳表は `SqlState.classify`。
    ///
    /// WhyNot: message が null の時に class 名を入れるのは、sqlite-jdbc が自分の失敗の一部を message 無しで投げ、空の `Other` ではどこを見ればよいか分からないから。
    ///
    pub def raiseSqlException(e: SQLException): a \ {IO, TransientDbErr, DbErr} =
        let message: String = e.getMessage();
        let said = if (Object.isNull(message)) e.getClass().getName() else message;
        DbError.raise(SqlState.classify({ code = e.getErrorCode(), message = said }))

    ///
    /// 文を送って断られた SQLException を翻訳して投げる。SchemaMismatch と Other には、断られた文の頭と尻尾を付ける。
    ///
    /// WhyNot: 文を全部の kind に付けないのは、制約違反は違反した物を自分で名指し、文が無くても探せるから。
    /// SQLite は解決できなかった名前（`no such column: led.hled`）を言うだけで、どの文だったかを言わないので、
    /// 名前と構文の失敗には文が無いと探す所が無い。
    ///
    /// WhyNot: 頭と尻尾を残すのは、`WITH` で始まる長い文どうしを分けるのが、最後の `SELECT` と `WHERE` の方だから。
    ///
    pub def raiseRefusal(sql: String, e: SQLException): a \ {IO, TransientDbErr, DbErr} =
        let message: String = e.getMessage();
        let said = if (Object.isNull(message)) e.getClass().getName() else message;
        let carried = "${said}: ${identify(sql)}";
        DbError.raise(match SqlState.classify({ code = e.getErrorCode(), message = said }) {
            case DbError.DbErrorKind.SchemaMismatch(_) => DbError.DbErrorKind.SchemaMismatch(carried)
            case DbError.DbErrorKind.Other(_)          => DbError.DbErrorKind.Other(carried)
            case kind                                  => kind
        })

    ///
    /// 文の頭と尻尾、110 文字ずつ。短ければ全部。
    ///
    pub def identify(sql: String): String =
        let ends = 110;
        let length = String.length(sql);
        if (length <= 2 * ends) sql
        else "${String.takeLeft(ends, sql)} … ${String.dropLeft(length - ends, sql)}"

}
