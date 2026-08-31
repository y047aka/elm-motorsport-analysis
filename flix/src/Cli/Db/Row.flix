/// Reading one row of a `Cli.Db.fetch` result. Every cell arrives as text, or
/// as nothing where the column was null, so what a query means is settled here
/// beside the query rather than at the boundary.
mod Cli.Db.Row {

    pub def optionalText(index: Int32, row: List[Option[String]]): Result[String, Option[String]] =
        match List.nth(index, row) {
            case Some(cell) => Ok(cell)
            case None       => Err("no column ${index} in the row")
        }

    /// A null column reads as the empty string, which is what the feed's own
    /// blank columns already decode to.
    pub def text(index: Int32, row: List[Option[String]]): Result[String, String] =
        optionalText(index, row) |> Result.map(Option.getWithDefault(""))

    pub def int(index: Int32, row: List[Option[String]]): Result[String, Int32] =
        forM(
            cell  <- optionalInt(index, row);
            value <- expect("column ${index} was null", cell)
        ) yield value

    pub def optionalInt(index: Int32, row: List[Option[String]]): Result[String, Option[Int32]] =
        match optionalText(index, row) {
            case Err(cause)     => Err(cause)
            case Ok(None)       => Ok(None)
            case Ok(Some(cell)) => parse(index, cell) |> Result.map(value -> Some(value))
        }

    def parse(index: Int32, cell: String): Result[String, Int32] =
        Int32.fromString(cell) |> expect("column ${index} is not a number: \"${cell}\"")

    pub def expect(message: String, value: Option[a]): Result[String, a] =
        match value {
            case Some(x) => Ok(x)
            case None    => Err(message)
        }

}
