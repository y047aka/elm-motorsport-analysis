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
    use Sqlitefx.Decoder
    use Sqlitefx.Row
    use Sqlitefx.Row.Row
    use Sqlitefx.SqlValue

    pub def row(names: List[String], cells: List[Option[String]]): Row =
        Row.makeRows(names, values(cells) :: Nil) |> List.head |> Option.getWithDefault({ columns = Map#{}, cells = Vector#{} })

    /// The cells under the labels the projection's clause gives its columns: the text of each, or what follows its `AS`.
    pub def answering(p: p, cells: List[Option[String]]): Row with Sql.Project[p] =
        let labels = Decoder.selectList(Sql.Project.decoder(p)) |> List.map(item ->
            match List.reverse(String.splitOn({substr = " AS "}, item)) {
                case label :: _ => label
                case Nil        => item
            });
        row(labels, cells)

    def values(cells: List[Option[String]]): List[SqlValue] =
        cells |> List.map(cell -> match cell {
            case Some(text) => SqlValue.Str(text)
            case None       => SqlValue.Null
        })

}
