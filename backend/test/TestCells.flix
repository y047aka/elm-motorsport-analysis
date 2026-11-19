/// The cells a reading is handed, in the shape the schema writes them: text,
/// and nothing where the column was null.
///
/// A driver answers a column of this schema in text too, since that is what the
/// load bound; `Db.TestJdbc` is where the typed answers are driven.
///
/// A row carries the labels its columns come back under, since that is what a
/// reading looks a cell up by; `answering` takes them off the projection the
/// test decodes, which is what a database answers it with.
pub mod TestCells {
    use Lite3fx.Row
    use Lite3fx.Row.Row
    use Lite3fx.SqlValue

    pub def row(names: List[String], cells: List[Option[String]]): Row =
        Row.of(names, values(cells))

    /// The cells under the labels `sel` names its own columns by.
    pub def answering(sel: Sql.Sel[a], cells: List[Option[String]]): Row =
        row(Sql.labels(sel), cells)

    def values(cells: List[Option[String]]): List[SqlValue] =
        cells |> List.map(cell -> match cell {
            case Some(text) => SqlValue.Str(text)
            case None       => SqlValue.Null
        })

}
