pub mod Sqlitefx.SqlValue {

    use Sqlitefx.Date
    use Sqlitefx.Timestamp
    use Sqlitefx.Uuid

    ///
    /// プレースホルダに渡す値と、結果セットのセルの値。行きと帰りで同じ型を使い、JDBC との型対応表を 1 つにする。
    ///
    /// WhyNot: Timestamp を `OffsetDateTime`、Decimal を `java.math.BigDecimal` で持たないのは、
    /// Java 型を payload に置くと `Eq` を derive できず、テストハンドラが記録した Statement を比較できなくなるから。
    /// Java 型との変換は JDBC ハンドラの内側に閉じる。
    ///
    pub enum SqlValue with Eq, Order, ToString {
        /// SQL の NULL。型が付かない（結果セットのセルは列の型が分かっているので、これで足りる）
        case Null
        /// 型の付いた SQL の NULL。`Option` の引数の None がこれになる
        ///
        /// WhyNot: SQLite の NULL に型は無いが `Null` と分けておくのは、生成コードと `DbTest` の記録がどの型の引数の None だったかを持てるようにするため。送るときは同じ NULL になる。
        case NullOf(NullType)
        case Bool(Bool)
        case Int32(Int32)
        case Int64(Int64)
        case Float64(Float64)
        /// 金額など精度が要る数。TEXT で持つ
        case Decimal(BigDecimal)
        case Str(String)
        /// BLOB
        case Bytes(Vector[Int8])
        /// 時刻。UTC の epoch マイクロ秒を INTEGER で持つ
        case Timestamp(Int64)
        /// 日付。1970-01-01 からの日数を INTEGER で持つ
        case Date(Int32)
        /// UUID の 36 文字の文字列表現。TEXT で持つ
        case Uuid(String)
        /// JSON の素の文字列。TEXT で持つ
        case Json(String)
        /// 整数の配列。JSON の配列の TEXT で送り、`IN (SELECT value FROM json_each(:ids))` で使う
        case Int64Array(List[Int64])
        /// 文字列の配列。JSON の配列の TEXT で送る
        case StrArray(List[String])
        /// 整数の配列。JSON の配列の TEXT で送る
        case Int32Array(List[Int32])
        /// JSON の配列。要素は JSON の素の文字列。`json_each($1)` で複数行を 1 文に渡す用
        case JsonArray(List[String])
    }

    ///
    /// NULL に付ける型。case 名は SqlValue の値の case と揃えてある（生成器が case 名から綴りを作る）。
    /// JDBC の `setNull` に渡す `java.sql.Types` への対応は JdbcConvert が持つ。
    ///
    pub enum NullType with Eq, Order, ToString {
        case Bool
        case Int32
        case Int64
        case Float64
        case Decimal
        case Str
        case Bytes
        case Timestamp
        case Date
        case Uuid
        case Json
        case Int64Array
        case StrArray
        case Int32Array
        case JsonArray
    }

    // ---- 意味を持つ型からの包み。生成コードと Col が使う ----

    ///
    /// `Option` の引数を SqlValue に。Some は `wrap` で包み、None は型の付いた NULL。
    /// 生成コードが `.q` の `Option[T]` の引数に使う。
    ///
    pub def ofOption(nullType: NullType, wrap: a -> SqlValue \ ef, value: Option[a]): SqlValue \ ef =
        match value {
            case Some(inner) => wrap(inner)
            case None => SqlValue.NullOf(nullType)
        }

    pub def ofTimestamp(t: Timestamp.Timestamp): SqlValue = SqlValue.Timestamp(Timestamp.toEpochMicros(t))
    pub def ofDate(d: Date.Date): SqlValue = SqlValue.Date(Date.toEpochDay(d))
    pub def ofUuid(u: Uuid.Uuid): SqlValue = SqlValue.Uuid(Uuid.toText(u))
    pub def ofJson(j: Util.Json.Json): SqlValue = SqlValue.Json(Util.Json.toCompactString(j))
    pub def ofJsonArray(js: List[Util.Json.Json]): SqlValue = SqlValue.JsonArray(List.map(Util.Json.toCompactString, js))

    ///
    /// デコーダのエラーメッセージに出す型名。
    ///
    pub def typeName(value: SqlValue): String = match value {
        case SqlValue.Null => "NULL"
        case SqlValue.NullOf(_) => "NULL"
        case SqlValue.Bool(_) => "Bool"
        case SqlValue.Int32(_) => "Int32"
        case SqlValue.Int64(_) => "Int64"
        case SqlValue.Float64(_) => "Float64"
        case SqlValue.Decimal(_) => "Decimal"
        case SqlValue.Str(_) => "Str"
        case SqlValue.Bytes(_) => "Bytes"
        case SqlValue.Timestamp(_) => "Timestamp"
        case SqlValue.Date(_) => "Date"
        case SqlValue.Uuid(_) => "Uuid"
        case SqlValue.Json(_) => "Json"
        case SqlValue.Int64Array(_) => "Int64Array"
        case SqlValue.StrArray(_) => "StrArray"
        case SqlValue.Int32Array(_) => "Int32Array"
        case SqlValue.JsonArray(_) => "JsonArray"
    }

    ///
    /// NULL かどうか。
    ///
    pub def isNull(value: SqlValue): Bool = match value {
        case SqlValue.Null => true
        case SqlValue.NullOf(_) => true
        case _ => false
    }

    ///
    /// Bool の値を取り出す。SQLite は真偽を INTEGER の 0 / 1 で持つので、0 と 1 の整数も読む。それ以外は None。
    ///
    pub def asBool(value: SqlValue): Option[Bool] = match value {
        case SqlValue.Bool(b) => Some(b)
        case SqlValue.Int32(0) => Some(false)
        case SqlValue.Int32(1) => Some(true)
        case SqlValue.Int64(0i64) => Some(false)
        case SqlValue.Int64(1i64) => Some(true)
        case _ => None
    }

    ///
    /// Int32 の値を取り出す。Int64 で来ても Int32 に収まれば読む（sqlite-jdbc は式の結果を Long で返す事がある）。
    ///
    pub def asInt32(value: SqlValue): Option[Int32] = match value {
        case SqlValue.Int32(i) => Some(i)
        case SqlValue.Int64(i) if i >= Int32.toInt64(Int32.minValue()) and i <= Int32.toInt64(Int32.maxValue()) => Some(Int64.clampToInt32(min = Int32.minValue(), max = Int32.maxValue(), i))
        case _ => None
    }

    ///
    /// Int64 の値を取り出す。Int32 も広げて返す（sqlite-jdbc は 32 bit に収まる整数を Integer で返すので、同じ列でも値によって Int32 で来る）。
    ///
    pub def asInt64(value: SqlValue): Option[Int64] = match value {
        case SqlValue.Int64(i) => Some(i)
        case SqlValue.Int32(i) => Some(Int32.toInt64(i))
        case _ => None
    }

    ///
    /// Float64 の値を取り出す。整数も広げて読む（REAL の列でも、小数部の無い値を式が INTEGER で返す事がある）。
    ///
    pub def asFloat64(value: SqlValue): Option[Float64] = match value {
        case SqlValue.Float64(f) => Some(f)
        case SqlValue.Int32(i) => Some(Int32.toFloat64(i))
        case SqlValue.Int64(i) => Some(Int64.toFloat64(i))
        case _ => None
    }

    ///
    /// Decimal の値を取り出す。TEXT の数字と整数も読む（Decimal は TEXT で送るので、読み戻すと Str で来る）。
    ///
    /// WhyNot: REAL を読まないのは、REAL に落ちた時点で桁が失われていて、Decimal として返すと正確な値に見えてしまうから。
    ///
    pub def asDecimal(value: SqlValue): Option[BigDecimal] = match value {
        case SqlValue.Decimal(d) => Some(d)
        case SqlValue.Str(s) => BigDecimal.fromString(s)
        case SqlValue.Int32(i) => Some(Int32.toBigDecimal(i))
        case SqlValue.Int64(i) => Some(Int64.toBigDecimal(i))
        case _ => None
    }

    ///
    /// 文字列の値を取り出す。型が違えば None。
    ///
    pub def asStr(value: SqlValue): Option[String] = match value {
        case SqlValue.Str(s) => Some(s)
        case _ => None
    }

    ///
    /// BLOB の値を取り出す。型が違えば None。
    ///
    pub def asBytes(value: SqlValue): Option[Vector[Int8]] = match value {
        case SqlValue.Bytes(b) => Some(b)
        case _ => None
    }

    ///
    /// Timestamp（epoch マイクロ秒）を取り出す。INTEGER で持つので整数も読む。
    ///
    pub def asTimestamp(value: SqlValue): Option[Int64] = match value {
        case SqlValue.Timestamp(t) => Some(t)
        case SqlValue.Int64(t) => Some(t)
        case SqlValue.Int32(t) => Some(Int32.toInt64(t))
        case _ => None
    }

    ///
    /// Date（1970-01-01 からの日数）を取り出す。INTEGER で持つので整数も読む。
    ///
    pub def asDate(value: SqlValue): Option[Int32] = match value {
        case SqlValue.Date(d) => Some(d)
        case SqlValue.Int32(_) => asInt32(value)
        case SqlValue.Int64(_) => asInt32(value)
        case _ => None
    }

    ///
    /// UUID の文字列表現を取り出す。TEXT で持つので文字列も読む（形は `Uuid.fromString` が確かめる）。
    ///
    pub def asUuid(value: SqlValue): Option[String] = match value {
        case SqlValue.Uuid(u) => Some(u)
        case SqlValue.Str(u) => Some(u)
        case _ => None
    }

    ///
    /// JSON の素の文字列を取り出す。TEXT で持つので文字列も読む（JSON として読めるかは `Decoder.json` が確かめる）。
    ///
    pub def asJson(value: SqlValue): Option[String] = match value {
        case SqlValue.Json(j) => Some(j)
        case SqlValue.Str(j) => Some(j)
        case _ => None
    }

    ///
    /// 整数の配列を取り出す。JSON の数の配列の TEXT も読む。
    ///
    pub def asInt64Array(value: SqlValue): Option[List[Int64]] = match value {
        case SqlValue.Int64Array(xs) => Some(xs)
        case SqlValue.Str(text) => Util.Json.decode(text) |> Result.toOption
        case _ => None
    }

    ///
    /// 文字列の配列を取り出す。JSON の文字列の配列の TEXT も読む。
    ///
    pub def asStrArray(value: SqlValue): Option[List[String]] = match value {
        case SqlValue.StrArray(xs) => Some(xs)
        case SqlValue.Str(text) => Util.Json.decode(text) |> Result.toOption
        case _ => None
    }

    ///
    /// 整数の配列（Int32）を取り出す。JSON の数の配列の TEXT も読む。
    ///
    pub def asInt32Array(value: SqlValue): Option[List[Int32]] = match value {
        case SqlValue.Int32Array(xs) => Some(xs)
        case SqlValue.Str(text) => Util.Json.decode(text) |> Result.toOption
        case _ => None
    }

    ///
    /// JSON の配列の要素（JSON の素の文字列）を取り出す。JSON の配列の TEXT も読み、要素を 1 つずつ素の文字列に戻す。
    ///
    pub def asJsonArray(value: SqlValue): Option[List[String]] = match value {
        case SqlValue.JsonArray(xs) => Some(xs)
        case SqlValue.Str(text) => match Util.Json.parse(text) {
            case Ok(Util.Json.Json.JArray(elements)) => Some(Vector.toList(elements) |> List.map(Util.Json.toCompactString))
            case _ => None
        }
        case _ => None
    }

}
