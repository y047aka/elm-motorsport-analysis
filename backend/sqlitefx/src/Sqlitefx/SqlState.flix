pub mod Sqlitefx.SqlState {

    use Sqlitefx.DbError.DbErrorKind
    use Sqlitefx.DbError.TransientKind

    ///
    /// SQLite の result code とメッセージを、どの op に翻訳するかの enum に落とす。純粋なので DB 無しでテストする。
    ///
    /// result code の一覧: https://www.sqlite.org/rescode.html
    ///
    /// WhyNot: SQLSTATE を見ないのは、SQLite に SQLSTATE が無く、sqlite-jdbc の `getSQLState` は何も返さないから。
    /// 見るのは `getErrorCode`（result code）で、拡張 code は下位 1 バイトが基本 code（`SQLITE_BUSY_SNAPSHOT` = 517 は 5）。
    ///
    /// WhyNot: BUSY / LOCKED を Deadlock でなく Timeout に入れるのは、`busy_timeout` の間ロックを待って取れなかった物で、PG の lock_timeout（55P03）と同じく、同じ文をもう一度送れば通りうる物だから。待った ms はメッセージに無いので 0。
    ///
    /// WhyNot: CANTOPEN を ConnectionLost に入れるのは、ファイルの DB にとって「開けない」が PG の「届かない」に当たり、ディレクトリが後から用意されれば同じ接続先で通るから。
    ///
    pub def classify(error: { code = Int32, message = String }): DbErrorKind =
        let code = error#code;
        let message = error#message;
        let primary = Int32.remainder(code, 256);
        if (primary == busy() or primary == locked())
            DbErrorKind.Transient(TransientKind.Timeout(0))
        else if (primary == cantOpen())
            DbErrorKind.Transient(TransientKind.ConnectionLost(message))
        else if (primary == constraint())
            constraintKind(code, message)
        else if (primary == sqliteError() and missingSchema(message))
            DbErrorKind.SchemaMismatch(message)
        else
            DbErrorKind.Other(message)

    def sqliteError(): Int32 = 1
    def busy(): Int32 = 5
    def locked(): Int32 = 6
    def cantOpen(): Int32 = 14
    def constraint(): Int32 = 19

    def constraintCheck(): Int32 = 275
    def constraintForeignKey(): Int32 = 787
    def constraintNotNull(): Int32 = 1299
    def constraintPrimaryKey(): Int32 = 1555
    def constraintUnique(): Int32 = 2067
    def constraintRowid(): Int32 = 2579

    ///
    /// 制約違反の種類。拡張 code があればそれで、基本 code だけならメッセージの文言で決める。
    ///
    /// WhyNot: 主キーと rowid の重複を UniqueViolation に入れるのは、PG では主キーの重複も 23505 だから。
    ///
    def constraintKind(code: Int32, message: String): DbErrorKind = match code {
        case c if c == constraintUnique() or c == constraintPrimaryKey() or c == constraintRowid() =>
            DbErrorKind.UniqueViolation(constraintName(message))
        case c if c == constraintForeignKey() => DbErrorKind.ForeignKeyViolation(constraintName(message))
        case c if c == constraintNotNull()    => DbErrorKind.NotNullViolation(constraintName(message))
        case c if c == constraintCheck()      => DbErrorKind.CheckViolation(constraintName(message))
        case _                                => kindFromMessage(message)
    }

    ///
    /// WhyNot: 文言を頭で照合せず含むかで見るのは、sqlite-jdbc が SQLite の文を自分の文で包むから（`[SQLITE_CONSTRAINT_UNIQUE] A UNIQUE constraint failed (UNIQUE constraint failed: t.k)`）。
    ///
    def kindFromMessage(message: String): DbErrorKind =
        if (String.contains(substr = "UNIQUE constraint failed", message))
            DbErrorKind.UniqueViolation(constraintName(message))
        else if (String.contains(substr = "FOREIGN KEY constraint failed", message))
            DbErrorKind.ForeignKeyViolation(constraintName(message))
        else if (String.contains(substr = "NOT NULL constraint failed", message))
            DbErrorKind.NotNullViolation(constraintName(message))
        else if (String.contains(substr = "CHECK constraint failed", message))
            DbErrorKind.CheckViolation(constraintName(message))
        else
            DbErrorKind.Other(message)

    ///
    /// 無い表・列・関数。`no such table: t`、`no such column: c`、`no such function: f`、`table t has no column named c`。
    ///
    def missingSchema(message: String): Bool =
        String.contains(substr = "no such table", message)
            or String.contains(substr = "no such column", message)
            or String.contains(substr = "no such function", message)
            or String.contains(substr = "has no column named", message)

    ///
    /// 違反のメッセージから、何が違反したかを取り出す。`failed:` の後ろ、sqlite-jdbc が閉じる `)` の前。
    /// UNIQUE / NOT NULL は `表.列`（複数列なら `, ` 区切り）、名前付きの CHECK は制約名。
    /// `failed:` が無ければ（FOREIGN KEY と名前の無い CHECK）SQLite 自身の文を返す（何も名指さないが、情報は捨てない）。
    ///
    /// WhyNot: PG のように制約名を返さないのは、SQLite が UNIQUE と NOT NULL の違反に制約名を出さず、出すのは違反した列だから。利用側が `onConstraint` で照合するのは `users.email` の形になる。
    ///
    pub def constraintName(message: String): String =
        match String.splitOn(substr = "failed:", message) |> List.drop(1) |> List.last {
            case None       => sqliteSentence(message)
            case Some(rest) => beforeClose(rest)
        }

    ///
    /// sqlite-jdbc が `[SQLITE_…] 自分の文 (SQLite の文)` と包んでいれば括弧の中、包んでいなければ全体。
    ///
    def sqliteSentence(message: String): String =
        match String.splitOn(substr = "(", message) |> List.drop(1) |> List.last {
            case Some(inner) if String.contains(substr = ")", inner) => beforeClose(inner)
            case _ => message
        }

    def beforeClose(text: String): String =
        String.splitOn(substr = ")", text) |> List.head |> Option.getWithDefault(text) |> String.trim

}
