/// The cells a reading is handed, in the shape the schema writes them: text,
/// and nothing where the column was null.
///
/// A driver answers a column of this schema in text too, since that is what the
/// load bound; `Db.TestJdbc` is where the typed answers are driven.
pub mod TestCells {

    use Db.Row.Row
    use Db.Value

    pub def row(cells: List[Option[String]]): Row =
        Row.ofCells(cells |> List.map(cell -> match cell {
            case Some(text) => Value.Text(text)
            case None       => Value.Null
        }))

}
