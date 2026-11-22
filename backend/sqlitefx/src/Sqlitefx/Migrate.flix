///
/// migrations/*.sql を DB に当てる。適用済みは `sqlitefx_migrations` に記録し、前進のみ、1 ファイル 1 Tx。
/// 同時に走る migrate どうしは、ファイルごとに `BEGIN IMMEDIATE` で書き込みのロックを取り、取った後で記録を読み直して並ぶ。
/// 生成器 `gen` と同じファイルを読むが、パーサは通さず JDBC の Statement にそのまま渡す（トリガも当たる）。
///
/// WhyNot: `Sql.execute` を使わないのは、`$n` を `?` に書き換える経路なので、文字列リテラルの外の `$` を含む文が壊れるから。
///
/// WhyNot: PG のように migrate 全体を 1 つのロックで囲まないのは、SQLite に接続を跨いで持てる advisory lock が無く、持てる一番近い物が書き込みのロックで、それを全体で持つと 1 ファイル 1 Tx でなくなるから。
/// ファイルごとにロックを取り、取った後で「もう当たっているか」を読み直せば、2 つの migrate が同じファイルを 2 回当てる事は無い。
///
pub mod Sqlitefx.Migrate {

    use Sqlitefx.DbErr
    use Sqlitefx.DbError
    use Sqlitefx.Decoder
    use Sqlitefx.Jdbc
    use Sqlitefx.SqlValue
    use Sqlitefx.Timestamp
    use Sqlitefx.TransientDbErr

    import java.sql.Connection
    import java.sql.Statement
    import java.sql.SQLException
    import java.security.MessageDigest
    import java.nio.charset.StandardCharsets
    import java.lang.System

    use Sqlitefx.SqlValue.SqlValue

    ///
    /// migrate 固有の失敗。SQL の失敗は DbErr のまま。
    ///
    pub eff MigrateErr {
        /// 適用済みのファイルが書き換わっている（version）
        def checksumMismatch(version: String): Void
        /// 記録にあるがディレクトリに無い（改名か削除）
        def missingFile(version: String): Void
        /// `NNN_name.sql` の形でない
        def invalidFileName(name: String): Void
        /// 同じ番号のファイルが 2 つ以上ある（ブランチのマージで起きる）
        def duplicateNumber(names: List[String]): Void
        /// check で未適用が残っている
        def pending(versions: List[String]): Void
    }

    ///
    /// 接続先と、DDL がロックを待つ上限。
    ///
    /// - `connection`: 専用の接続を 1 本開く先
    /// - `lockTimeoutMs`: `busy_timeout`。書き込みのロックを待つ上限。他の migrate や長い書き込みの後ろで待ち続けないため
    ///
    pub type alias Config = { connection = Jdbc.ConnectionConfig, lockTimeoutMs = Int32 }

    ///
    /// 既定はロックの待ち 10 秒。
    ///
    pub def defaultConfig(connection: Jdbc.ConnectionConfig): Config =
        { connection = connection, lockTimeoutMs = 10000 }

    ///
    /// 1 ファイルの状態。`--status` の 1 行。
    ///
    pub enum Status with Eq, Order, ToString {
        /// (version, 適用時刻, かかった ms)
        case Applied(String, Timestamp.Timestamp, Int32)
        case Pending(String)
    }

    ///
    /// 読んだファイル。
    ///
    /// - `version`: ファイル名。記録テーブルのキー
    /// - `sql`: 全文
    /// - `checksum`: 正規化した全文の SHA-256（hex）
    /// - `noTransaction`: 先頭行が `-- sqlitefx:no-transaction`
    ///
    type alias MigrationFile = { version = String, sql = String, checksum = String, noTransaction = Bool }

    ///
    /// 記録テーブルの 1 行。
    ///
    type alias Applied = { version = String, checksum = String, appliedAt = Timestamp.Timestamp, executionMs = Int32 }

    // ---- 入口 ----

    ///
    /// 未適用のファイルを番号順に当て、当てた version を返す。専用の接続を開き、必ず閉じる。
    /// 適用済みのファイルが書き換わっていれば何も当てずに checksumMismatch。
    /// 同時に走った別の migrate が先に当てたファイルは、当てずに飛ばす（返す version に入らない）。
    ///
    pub def apply(config: Config, dir: String): List[String] \ {IO, Fs.ReadFile.ReadFile, Fs.DirList.DirList, TransientDbErr, DbErr, MigrateErr} =
        let files = loadFiles(dir);
        let connection = { pragmas = config#connection#pragmas ::: List#{"busy_timeout = ${config#lockTimeoutMs}"} | config#connection };
        Jdbc.withConnection(connection, conn -> {
            ensureTable(conn);
            let applied = readApplied(conn);
            verifyApplied(files, applied);
            pendingOf(files, applied) |> List.filter(file -> applyOne(conn, file)) |> List.map(file -> file#version)
        })

    ///
    /// 全ファイルの状態。適用済みは記録の時刻と所要時間付き。ファイル名の順。
    ///
    pub def status(conn: Connection, dir: String): List[Status] \ {IO, Fs.ReadFile.ReadFile, Fs.DirList.DirList, TransientDbErr, DbErr, MigrateErr} =
        let files = loadFiles(dir);
        ensureTable(conn);
        let applied = readApplied(conn);
        List.map(file -> match List.find(row -> row#version == file#version, applied) {
            case Some(row) => Status.Applied(row#version, row#appliedAt, row#executionMs)
            case None => Status.Pending(file#version)
        }, files)

    ///
    /// 書かずに確かめる。未適用があれば pending、適用済みが書き換わっていれば checksumMismatch、記録にあるがファイルが無ければ missingFile。
    /// CI のデプロイ前と、アプリの起動時に呼ぶ。
    ///
    pub def check(conn: Connection, dir: String): Unit \ {IO, Fs.ReadFile.ReadFile, Fs.DirList.DirList, TransientDbErr, DbErr, MigrateErr} =
        let files = loadFiles(dir);
        ensureTable(conn);
        let applied = readApplied(conn);
        verifyApplied(files, applied);
        match pendingOf(files, applied) {
            case Nil => ()
            case waiting => MigrateErr.pending(List.map(file -> file#version, waiting))
        }

    ///
    /// MigrateErr を 1 層の Result に落とす。境界（main / テスト）で使う。
    ///
    pub def runWithResult(thunk: Unit -> a \ ef): Result[String, a] \ ef - MigrateErr =
        run {
            Ok(thunk())
        } with handler MigrateErr {
            def checksumMismatch(version, _resume) = Err("checksum mismatch: ${version}")
            def missingFile(version, _resume) = Err("missing file: ${version}")
            def invalidFileName(name, _resume) = Err("invalid file name: ${name} (expected NNN_name.sql)")
            def duplicateNumber(names, _resume) = Err("duplicate number: ${List.join(", ", names)}")
            def pending(versions, _resume) = Err("pending: ${List.join(", ", versions)}")
        }

    // ---- ファイル ----

    ///
    /// ディレクトリ直下の .sql を名前順に読む。形式が違う名前が 1 つでもあれば invalidFileName、番号が重なれば duplicateNumber。
    ///
    def loadFiles(dir: String): List[MigrationFile] \ {IO, Fs.ReadFile.ReadFile, Fs.DirList.DirList, DbErr, MigrateErr} =
        let names = listSqlFiles(dir);
        List.forEach(name -> if (isValidFileName(name)) () else MigrateErr.invalidFileName(name), names);
        match duplicateNumbers(names) {
            case Nil => ()
            case duplicates :: _ => MigrateErr.duplicateNumber(duplicates)
        };
        List.map(name -> {
            let sql = match Fs.ReadFile.read("${dir}/${name}") {
                case Ok(text) => text
                case Err(e) => DbErr.other("cannot read ${dir}/${name}: ${e}")
            };
            { version = name, sql = sql, checksum = checksum(sql), noTransaction = hasNoTransactionMarker(sql) }
        }, names)

    ///
    /// ディレクトリ直下の .sql を名前順に。
    ///
    pub def listSqlFiles(dir: String): List[String] \ {Fs.DirList.DirList, DbErr} =
        match Fs.DirList.list(dir) {
            case Ok(entries) => entries |> List.filter(name -> String.endsWith(suffix = ".sql", name)) |> List.sort
            case Err(e) => DbErr.other("cannot list ${dir}: ${e}")
        }

    ///
    /// 同じ番号を持つファイル名の組。`001_a.sql` と `0001_b.sql` は同じ番号。形式が違う名前は見ない。重なりが無ければ Nil。
    ///
    pub def duplicateNumbers(names: List[String]): List[List[String]] =
        names
            |> List.filter(isValidFileName)
            |> List.groupBy(numberOf)
            |> List.map(Nel.toList)
            |> List.filter(group -> List.length(group) > 1)
            |> List.map(List.sort)
            |> List.sort

    ///
    /// 次のファイル名。今ある最大の番号 + 1 を 3 桁のゼロ埋めで付ける。空なら 001。
    ///
    pub def nextFileName(names: List[String], name: String): String =
        let next = names |> List.filterMap(numberOf) |> List.maximum |> Option.getWithDefault(0) |> (n -> n + 1);
        "${String.padLeft(3, '0', "${next}")}_${name}.sql"

    ///
    /// `migrate new` に渡す名前。小文字・数字・`_` だけで、先頭は小文字。
    ///
    pub def isValidMigrationName(name: String): Bool =
        String.forAll(c -> isLowerAscii(c) or Char.isDigit(c) or c == '_', name)
            and (String.toList(name) |> List.head |> Option.map(isLowerAscii) |> Option.getWithDefault(false))

    def isLowerAscii(c: Char): Bool = c >= 'a' and c <= 'z'

    ///
    /// 先頭の `NNN` を数として。形式が違えば None。
    ///
    def numberOf(name: String): Option[Int32] =
        if (isValidFileName(name))
            String.indexOf(substr = "_", name) |> Option.flatMap(underscore -> String.takeLeft(underscore, name) |> Int32.fromString)
        else None

    ///
    /// `NNN_name.sql`。番号は 3 桁以上のゼロ埋め。文字列順で並べても番号順になるように形を固定する。
    ///
    pub def isValidFileName(name: String): Bool =
        match String.indexOf(substr = "_", name) {
            case Some(underscore) =>
                let digits = String.takeLeft(underscore, name);
                let rest = String.dropLeft(underscore + 1, name);
                String.length(digits) >= 3 and String.forAll(Char.isDigit, digits) and String.endsWith(suffix = ".sql", rest) and String.length(rest) > 4
            case None => false
        }

    ///
    /// 先頭の空でない行が `-- sqlitefx:no-transaction` か。
    ///
    pub def hasNoTransactionMarker(sql: String): Bool =
        String.splitOn(substr = "\n", sql)
            |> List.map(String.trim)
            |> List.find(line -> not String.isEmpty(line))
            |> Option.map(line -> line == "-- sqlitefx:no-transaction")
            |> Option.getWithDefault(false)

    ///
    /// 正規化した全文の SHA-256。CRLF を LF に、各行末の空白と末尾の空行を落とす。コメントや空白の圧縮はしない（文字列リテラルを壊す）。
    ///
    pub def checksum(sql: String): String \ IO =
        let normalized = sql
            |> String.replace(src = "\r\n", dst = "\n")
            |> String.splitOn(substr = "\n")
            |> List.map(String.trimRight)
            |> List.reverse |> List.dropWhile(String.isEmpty) |> List.reverse
            |> List.join("\n");
        let bytes: Array[Int8, Static] = normalized.getBytes(StandardCharsets.UTF_8);
        let digest = MessageDigest.getInstance("SHA-256");
        let hashed: Array[Int8, Static] = digest.digest(bytes);
        Array.toList(hashed) |> List.map(hex) |> List.join("")

    def hex(byte: Int8): String =
        let value = Int8.toInt32(byte) |> Int32.bitwiseAnd(255);
        let digit = n -> String.charAt(n, "0123456789abcdef") |> Char.toString;
        digit(value / 16) + digit(Int32.bitwiseAnd(value, 15))

    // ---- 記録 ----

    def ensureTable(conn: Connection): Unit \ {IO, TransientDbErr, DbErr} =
        executeRaw(conn, "CREATE TABLE IF NOT EXISTS sqlitefx_migrations (version TEXT PRIMARY KEY, checksum TEXT NOT NULL, applied_at INTEGER NOT NULL, execution_ms INTEGER NOT NULL)")

    def readApplied(conn: Connection): List[Applied] \ {IO, TransientDbErr, DbErr} =
        let decoder = forA (
            version <- Decoder.str("version");
            sum <- Decoder.str("checksum");
            appliedAt <- Decoder.timestamp("applied_at");
            executionMs <- Decoder.int32("execution_ms")
        ) yield { version = version, checksum = sum, appliedAt = appliedAt, executionMs = executionMs };
        let rows = Jdbc.fetchRows(conn, "SELECT version, checksum, applied_at, execution_ms FROM sqlitefx_migrations ORDER BY version", Nil);
        match Decoder.decodeRows(decoder, rows) {
            case Ok(applied) => applied
            case Err(error) => DbErr.decodeError(Decoder.errorColumn(error), Decoder.describeError(error))
        }

    ///
    /// 適用済みの記録とファイルを突き合わせる。記録にあるがファイルが無ければ missingFile、checksum が違えば checksumMismatch。
    ///
    def verifyApplied(files: List[MigrationFile], applied: List[Applied]): Unit \ MigrateErr =
        List.forEach(row -> match List.find(file -> file#version == row#version, files) {
            case None => MigrateErr.missingFile(row#version)
            case Some(file) => if (file#checksum == row#checksum) () else MigrateErr.checksumMismatch(row#version)
        }, applied)

    ///
    /// 記録に無いファイル。番号が適用済みより小さくても当てる（ブランチのマージで後から割り込む）。
    ///
    def pendingOf(files: List[MigrationFile], applied: List[Applied]): List[MigrationFile] =
        List.filter(file -> not List.exists(row -> row#version == file#version, applied), files)

    ///
    /// 1 ファイルを当てて記録し、当てたかを返す。Tx ありなら書き込みのロックを取り、もう記録があれば当てずに false。
    /// 全文と記録の INSERT は同じ Tx に入る。
    ///
    /// WhyNot: `Tx.withTx` で囲まないのは、それが `setAutoCommit(false)` の deferred な BEGIN で、最初の読みでは書き込みのロックを取らないから。記録を読み直した後で 2 つの migrate がどちらも書こうとすると、片方が BUSY になる。
    ///
    /// WhyNot: no-transaction のファイルを並ばせないのは、`VACUUM` のように Tx の中で走らない文のための印で、ロックを持ったまま当てられないから。同時に走る migrate が同じファイルを当てうるので、そういう文は何度当てても同じ形に書く。
    ///
    /// WhyNot: `applied_at` を DB の `DEFAULT` でなくこちらの時刻で入れるのは、SQLite に PG の `now()` に当たるマイクロ秒の時刻を返す関数が無いから。
    ///
    def applyOne(conn: Connection, file: MigrationFile): Bool \ {IO, TransientDbErr, DbErr} =
        let started = System.currentTimeMillis();
        let apply = () -> if (isApplied(conn, file#version)) false else {
            executeRaw(conn, file#sql);
            let finished = System.currentTimeMillis();
            let elapsed = Int64.clampToInt32(min = 0, max = Int32.maxValue(), finished - started);
            discard Jdbc.executeStatement(conn, "INSERT INTO sqlitefx_migrations (version, checksum, applied_at, execution_ms) VALUES ($1, $2, $3, $4)",
                List#{SqlValue.Str(file#version), SqlValue.Str(file#checksum), SqlValue.Timestamp(finished * 1000i64), SqlValue.Int32(elapsed)});
            true
        };
        if (file#noTransaction)
            apply()
        else {
            executeRaw(conn, "BEGIN IMMEDIATE");
            match DbError.runWithKind(apply) {
                case Ok(applied) => { executeRaw(conn, "COMMIT"); applied }
                case Err(kind) => { discard DbError.runWithKind(() -> executeRaw(conn, "ROLLBACK")); DbError.raise(kind) }
            }
        }

    def isApplied(conn: Connection, version: String): Bool \ {IO, TransientDbErr, DbErr} =
        not List.isEmpty(Jdbc.fetchRows(conn, "SELECT 1 FROM sqlitefx_migrations WHERE version = $1", List#{SqlValue.Str(version)}))

    ///
    /// 生 SQL を JDBC の Statement にそのまま渡す。`;` で区切った複数文も全部当たる（`TestMigrate.testMigrateApplyThenNoop` の 001）。
    ///
    def executeRaw(conn: Connection, sql: String): Unit \ {IO, TransientDbErr, DbErr} =
        try {
            let statement: Statement = conn.createStatement();
            discard statement.executeUpdate(sql);
            statement.close()
        } catch {
            case e: SQLException => Jdbc.raiseSqlException(e)
        }

}
