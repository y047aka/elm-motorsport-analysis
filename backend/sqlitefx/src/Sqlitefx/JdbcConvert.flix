///
/// SqlValue と JDBC の型の変換。Java の型はこのモジュールの中に閉じる。
///
/// SQLite は値ごとに 5 つの記憶クラス（NULL / INTEGER / REAL / TEXT / BLOB）のどれかで持つ。送る側は SqlValue の case ごとに記憶クラスを 1 つに決め、読む側は SQLite がその値を持っていた記憶クラスで返す。意味の型（Bool / Timestamp / Json …）への戻しは `SqlValue.as*` が記憶クラスから行う。
///
/// | SqlValue | 記憶クラス | 中身 |
/// |---|---|---|
/// | Bool | INTEGER | 0 / 1 |
/// | Int32 / Int64 | INTEGER | |
/// | Float64 | REAL | |
/// | Decimal | TEXT | `toPlainString` |
/// | Str / Uuid / Json | TEXT | |
/// | Bytes | BLOB | |
/// | Timestamp | INTEGER | UTC の epoch マイクロ秒 |
/// | Date | INTEGER | 1970-01-01 からの日数 |
/// | Int64Array / StrArray / Int32Array / JsonArray | TEXT | JSON の配列。`json_each(?)` で行に開ける |
///
/// WhyNot: Decimal を REAL で送らないのは、REAL は 64 bit 浮動小数で桁が落ちるから。TEXT 型の列なら書いた文字列のまま残る。
///
/// WhyNot: Timestamp を ISO 8601 の TEXT にしないのは、SqlValue の中身がもともと epoch マイクロ秒で、INTEGER なら往復に解析が要らず、大小比較もそのまま効くから。SQLite の日付関数に渡すなら `datetime(t / 1000000, 'unixepoch', 'subsec')`。
///
/// WhyNot: 配列を JSON にするのは、SQLite に配列型が無く、PG の `= ANY($1)` に当たる書き方が `IN (SELECT value FROM json_each($1))` だから。
///
pub mod Sqlitefx.JdbcConvert {

    use Sqlitefx.Row
    use Sqlitefx.SqlValue

    import java.sql.PreparedStatement
    import java.sql.ResultSet
    import java.sql.ResultSetMetaData
    import java.sql.Types

    use Sqlitefx.SqlValue.SqlValue
    use Sqlitefx.Row.Row
    use Util.Json.ToJson.ToJson

    ///
    /// `$1` 形式のプレースホルダを JDBC の `?` に書き換え、出現順に並べ直したパラメータを返す。
    /// 同じ `$n` が 2 回出れば同じ値を 2 回並べる。単一引用符の文字列リテラルの中は触らない。
    /// 存在しない `$n` を参照していたら None（バインド時の範囲外エラーより先に、ここで派手に落とす）。
    ///
    /// `$n` が 1 つも無く、引用符の外の `?` が params と同じ数だけあれば、`?` を出てきた順に params に当てる（SQLite の位置のプレースホルダ）。
    /// `$n` と `?` が 1 つの文に混ざっていれば None、`?` の数と params の数が違っても None。
    ///
    /// WhyNot: sqlfx と同じく `$n` を正としながら `?` も受けるのは、文を断片から組み立てる側（値と `?` を対にして繋ぐ）が、
    /// 番号を振り直さずに渡せるから。番号は組み上がった文の中でしか決まらない。
    ///
    pub def rewritePlaceholders(sql: String, params: List[SqlValue]): Option[(String, List[SqlValue])] =
        let stripped = stripLineComments(sql);
        let paramVector = List.toVector(params);
        let (chars, refs, _, pending) = String.toList(stripped) |> List.foldLeft(step, (Nil, Nil, false, None));
        let (flushedChars, flushedRefs) = flushDigits(chars, refs, pending);
        let positional = bareQuestionMarks(stripped);
        let sqlOut = region rc {
            let sb = StringBuilder.empty(rc);
            List.forEach(ch -> StringBuilder.append(ch, sb), List.reverse(flushedChars));
            StringBuilder.toString(sb)
        };
        match (flushedRefs, positional) {
            case (Nil, 0) => Some((sqlOut, Nil))
            case (Nil, n) => if (n == List.length(params)) Some((sqlOut, params)) else None
            case (_, 0)   =>
                List.reverse(flushedRefs)
                    |> List.traverse(n -> Vector.nth(n - 1, paramVector))
                    |> Option.map(ordered -> (sqlOut, ordered))
            case _        => None
        }

    ///
    /// 単一引用符の外の `?` の数。
    ///
    def bareQuestionMarks(sql: String): Int32 =
        let (count, _) = String.toList(sql) |> List.foldLeft((acc, ch) -> {
            let (n, inQuote) = acc;
            if (ch == '\'') (n, not inQuote)
            else if (ch == '?' and not inQuote) (n + 1, inQuote)
            else (n, inQuote)
        }, (0, false));
        count

    ///
    /// 1 文字ずつ見て (出力文字の逆順, 参照した $n の逆順, 引用符の中か, 読みかけの $n の数字)。
    ///
    def step(state: (List[Char], List[Int32], Bool, Option[Int32]), ch: Char): (List[Char], List[Int32], Bool, Option[Int32]) =
        let (chars, refs, inQuote, digits) = state;
        match digits {
            case Some(n) if Char.isDigit(ch) => (chars, refs, inQuote, Some(n * 10 + Char.digit(radix = 10, ch) |> Option.getWithDefault(0)))
            case Some(_) =>
                let (flushedChars, flushedRefs) = flushDigits(chars, refs, digits);
                step((flushedChars, flushedRefs, inQuote, None), ch)
            case None =>
                if (ch == '\'')
                    (ch :: chars, refs, not inQuote, None)
                else if (ch == '$' and not inQuote)
                    (chars, refs, inQuote, Some(0))
                else
                    (ch :: chars, refs, inQuote, None)
        }

    ///
    /// `--` から行末までを落とす。コメントの中の `'` や `$1` を見ないため。単一引用符の中の `--` は残す。
    ///
    pub def stripLineComments(sql: String): String =
        let (chars, _, _) = String.toList(sql) |> List.foldLeft(commentStep, (Nil, false, false));
        List.reverse(chars) |> charsToString

    ///
    /// (出力の逆順, 引用符の中か, コメントの中か)。
    ///
    def commentStep(state: (List[Char], Bool, Bool), ch: Char): (List[Char], Bool, Bool) =
        let (chars, inQuote, inComment) = state;
        if (inComment)
            (if (ch == '\n') ch :: chars else chars, false, ch != '\n')
        else if (ch == '\'')
            (ch :: chars, not inQuote, false)
        else if (ch == '-' and not inQuote)
            match chars {
                case '-' :: rest => (rest, false, true)
                case _ => (ch :: chars, inQuote, false)
            }
        else
            (ch :: chars, inQuote, false)

    def charsToString(chars: List[Char]): String =
        region rc {
            let sb = StringBuilder.empty(rc);
            List.forEach(c -> StringBuilder.append(c, sb), chars);
            StringBuilder.toString(sb)
        }

    ///
    /// 読みかけの `$n` を確定する。数字が無い `$` はそのまま出力に戻す（`$$` の dollar quote 等）。
    ///
    def flushDigits(chars: List[Char], refs: List[Int32], digits: Option[Int32]): (List[Char], List[Int32]) =
        match digits {
            case Some(0) => ('$' :: chars, refs)
            case Some(n) => ('?' :: chars, n :: refs)
            case None => (chars, refs)
        }

    ///
    /// プレースホルダに値を順に埋める。添字は JDBC に合わせて 1 始まり。
    ///
    pub def bindParams(statement: PreparedStatement, params: List[SqlValue]): Unit \ IO =
        List.forEachWithIndex((index, value) -> bindParam(statement, index + 1, value), params)

    ///
    /// プレースホルダ 1 つに値を埋める。記憶クラスはモジュールの表の通り。
    ///
    /// WhyNot: 型の付いた NULL も `Types.NULL` で送るのは、SQLite の NULL に型が無く、sqlite-jdbc が `setNull` の型を見ないから。
    /// PG のように文脈から型を決められずに失敗する位置も無い。
    ///
    def bindParam(statement: PreparedStatement, index: Int32, value: SqlValue): Unit \ IO =
        match value {
            case SqlValue.Null => statement.setNull(index, Types.NULL)
            case SqlValue.NullOf(_) => statement.setNull(index, Types.NULL)
            case SqlValue.Bool(b) => statement.setInt(index, if (b) 1 else 0)
            case SqlValue.Int32(i) => statement.setInt(index, i)
            case SqlValue.Int64(i) => statement.setLong(index, i)
            case SqlValue.Float64(f) => statement.setDouble(index, f)
            case SqlValue.Decimal(d) => statement.setString(index, d.toPlainString())
            case SqlValue.Str(s) => statement.setString(index, s)
            case SqlValue.Bytes(bytes) => region rc {
                statement.setBytes(index, Vector.toArray(rc, bytes))
            }
            case SqlValue.Timestamp(micros) => statement.setLong(index, micros)
            case SqlValue.Date(days) => statement.setInt(index, days)
            case SqlValue.Uuid(s) => statement.setString(index, s)
            case SqlValue.Json(s) => statement.setString(index, s)
            case SqlValue.Int64Array(xs) => statement.setString(index, Util.Json.toCompactString(ToJson.toJson(xs)))
            case SqlValue.StrArray(xs) => statement.setString(index, Util.Json.toCompactString(ToJson.toJson(xs)))
            case SqlValue.Int32Array(xs) => statement.setString(index, Util.Json.toCompactString(ToJson.toJson(xs)))
            case SqlValue.JsonArray(xs) => statement.setString(index, "[${String.intercalate(",", xs)}]")
        }

    ///
    /// 結果セットを全部読んで Row のリストにする。読み終わったら接続から独立した値になる。
    ///
    pub def materialize(resultSet: ResultSet): List[Row] \ IO =
        let metadata: ResultSetMetaData = resultSet.getMetaData();
        let count: Int32 = metadata.getColumnCount();
        let indices = List.range(1, count + 1);
        let names = indices |> List.map(i -> { let label: String = metadata.getColumnLabel(i); label });
        let columns = Row.makeColumnIndex(names);
        readRows(resultSet, columns, List.toVector(names), indices, Nil)

    ///
    /// 1 行ずつ next() で進めながら読む。先頭に積んで最後に反転する。
    ///
    def readRows(resultSet: ResultSet, columns: Row.ColumnIndex, names: Vector[String], indices: List[Int32], acc: List[Row]): List[Row] \ IO =
        if (resultSet.next()) {
            let cells = indices |> List.map(i -> cell(resultSet, i)) |> List.toVector;
            readRows(resultSet, columns, names, indices, { columns = columns, names = names, cells = cells } :: acc)
        } else
            List.reverse(acc)

    ///
    /// 1 つのセルを、SQLite がその値を持っていた記憶クラスで読む。
    ///
    /// WhyNot: PG のように列の型から読み方を列ごとに 1 回決めないのは、SQLite の型が列でなく値に付くから。
    /// 宣言が INTEGER の列にも TEXT の値は入り、式の列には宣言が無い。sqlite-jdbc の `getObject` が値の記憶クラスでInteger / Long / Double / String / byte[] を返すので、それで分ける。
    ///
    /// WhyNot: Integer を Int32、Long を Int64 にするのは、sqlite-jdbc が 32 bit に収まる整数を Integer で返すから。
    /// `SqlValue.asInt64` は Int32 も広げて読む。
    ///
    def cell(resultSet: ResultSet, index: Int32): SqlValue \ IO =
        let found = resultSet.getObject(index);
        if (Object.isNull(found))
            SqlValue.Null
        else match found.getClass().getName() {
            case "java.lang.Integer" => SqlValue.Int32(resultSet.getInt(index))
            case "java.lang.Long"    => SqlValue.Int64(resultSet.getLong(index))
            case "java.lang.Double"  => SqlValue.Float64(resultSet.getDouble(index))
            case "java.lang.Float"   => SqlValue.Float64(resultSet.getDouble(index))
            case "[B"                => { let bytes = resultSet.getBytes(index); SqlValue.Bytes(Array.toVector(bytes)) }
            case _                   => { let s: String = resultSet.getString(index); SqlValue.Str(s) }
        }

}
