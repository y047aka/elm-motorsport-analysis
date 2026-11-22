/// A row as the database sent it: the columns it came under, and the cells
/// under them.
///
/// The labels are the driver's, which is what a reading looks a cell up by, and
/// they are what a failure names when it says which column it failed on.
///
/// SQLite types a value rather than a column, so a cell is what the driver
/// found and not what the schema declared. The readings take what they can of
/// that and say what they wanted in the failure they answer with.
pub mod Lite3fx.Row {

    use Lite3fx.SqlValue.SqlValue

    pub enum Row with Eq, ToString {
        case Row(List[String], List[SqlValue])
    }

    /// The row a statement came back as, names and cells.
    pub def of(columns: List[String], cells: List[SqlValue]): Row =
        Row.Row(columns, cells)

    /// A row of cells and no labels, which is what a reading is handed once the
    /// cells have been put in the order its projection names them.
    pub def ofCells(cells: List[SqlValue]): Row =
        Row.Row(Nil, cells)

    pub def cells(row: Row): List[SqlValue] =
        let Row.Row(_, values) = row;
        values

    /// The column names the driver reported, in the order the cells came in.
    pub def columnNames(row: Row): List[String] =
        let Row.Row(labels, _) = row;
        labels

    /// The number of cells the row still carries.
    pub def size(row: Row): Int32 =
        List.length(cells(row))

    /// The first cell, its column's name where the row carries names, and the
    /// row that is left.
    pub def uncons(row: Row): Option[(String, SqlValue, Row)] = match row {
        case Row.Row(_, Nil) => None
        case Row.Row(labels, value :: rest) =>
            let (name, left) = match labels {
                case head :: tail => (head, tail)
                case Nil          => ("", Nil)
            };
            Some((name, value, Row.Row(left, rest)))
    }

    /// The cell under a name. Two columns of the same name -- a join naming one from
    /// each side -- answer with the first.
    ///
    /// That is not how a projection is read. `Sql.decode` walks the projection and the
    /// row's columns together, so each of two columns sharing a name is read at its own
    /// place, which is what lets a statement project `ord` twice and get two answers.
    pub def get(row: Row, name: String): Option[SqlValue] =
        lookup(columnNames(row), cells(row), name)

    def lookup(names: List[String], cells: List[SqlValue], name: String): Option[SqlValue] =
        match (names, cells) {
            case (head :: tail, value :: rest) =>
                if (head == name) Some(value) else lookup(tail, rest, name)
            case _ => None
        }

    /// Whether every one of the first `n` cells carries nothing.
    pub def allNull(row: Row, n: Int32): Bool =
        List.take(n, cells(row)) |> List.forAll(SqlValue.isNull)

    /// The row without its first `n` cells.
    pub def drop(row: Row, n: Int32): Row =
        let Row.Row(labels, values) = row;
        Row.Row(List.drop(n, labels), List.drop(n, values))

}
