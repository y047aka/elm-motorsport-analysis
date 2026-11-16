/// A row as the database sent it: the columns it came under, and the cells
/// under them.
///
/// The readings go by position -- a query projects what it names, in that
/// order, and the cells come back in the same -- and the names are carried for
/// `get` and for the failure that has to say which column it failed on.
///
/// SQLite types a value rather than a column, so a cell is what the driver
/// found and not what the schema declared. `Sql`'s readings take what they can
/// of that and say what they wanted in the failure they answer with.
pub mod Db.Row {

    use Db.Value

    pub enum Row with Eq, ToString {
        case Row(List[String], List[Value])
    }

    /// The row a statement came back as, names and cells.
    pub def of(names: List[String], cells: List[Value]): Row =
        Row.Row(names, cells)

    /// A row of cells and no names, for a reading that takes only positions.
    pub def ofCells(cells: List[Value]): Row =
        Row.Row(Nil, cells)

    pub def cells(row: Row): List[Value] =
        let Row.Row(_, values) = row;
        values

    /// The column names the driver reported, in the order the cells came in.
    pub def names(row: Row): List[String] =
        let Row.Row(labels, _) = row;
        labels

    pub def isEmpty(row: Row): Bool =
        cells(row) == Nil

    /// The number of cells the row still carries.
    pub def size(row: Row): Int32 =
        List.length(cells(row))

    /// The first cell, its column's name where the row carries names, and the
    /// row that is left.
    pub def uncons(row: Row): Option[(String, Value, Row)] = match row {
        case Row.Row(_, Nil) => None
        case Row.Row(labels, value :: rest) =>
            let (name, left) = match labels {
                case head :: tail => (head, tail)
                case Nil          => ("", Nil)
            };
            Some((name, value, Row.Row(left, rest)))
    }

    /// The cell under a name. Two columns of the same name -- a join naming
    /// one from each side -- answer with the first.
    pub def get(row: Row, name: String): Option[Value] =
        lookup(names(row), cells(row), name)

    def lookup(names: List[String], cells: List[Value], name: String): Option[Value] =
        match (names, cells) {
            case (head :: tail, value :: rest) =>
                if (head == name) Some(value) else lookup(tail, rest, name)
            case _ => None
        }

    /// The cell as text, which is what every column of this schema was written
    /// as: the load binds text, and SQLite keeps what it is given. A null has no
    /// text, and the answer for one is the empty string.
    pub def textOf(value: Value): String = match value {
        case Value.Text(s)     => s
        case Value.Integer(n)  => "${n}"
        case Value.Real(n)     => "${n}"
        case Value.Boolean(b)  => if (b) "1" else "0"
        case Value.Json(xs)    => Db.jsonArray(xs)
        case Value.Null        => ""
        case Value.NullOf(_)   => ""
    }

    /// Whether the cell carries nothing.
    pub def isNull(value: Value): Bool = match value {
        case Value.Null      => true
        case Value.NullOf(_) => true
        case _               => false
    }

    /// Whether every one of the first `n` cells carries nothing.
    pub def allNull(row: Row, n: Int32): Bool =
        List.take(n, cells(row)) |> List.forAll(isNull)

    /// The row without its first `n` cells.
    pub def drop(row: Row, n: Int32): Row =
        let Row.Row(labels, values) = row;
        Row.Row(List.drop(n, labels), List.drop(n, values))

}
