/// Reading one row of a `Cli.Db.fetch` result. Every cell arrives as text, or
/// as nothing where the column was null, so what a query means is settled here
/// beside the query rather than at the boundary.
mod Cli.Db.Row {

    pub def optionalText(index: Int32, row: List[Option[String]]): Result[String, Option[String]] =
        match List.nth(index, row) {
            case Some(cell) => Ok(cell)
            case None       => Err("no column ${index} in the row")
        }

    pub def text(index: Int32, row: List[Option[String]]): Result[String, String] =
        forM(
            cell  <- optionalText(index, row);
            value <- expect("column ${index} was null", cell)
        ) yield value

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

    /// The driver renders a `boolean` column as `t` or `f`.
    pub def bool(index: Int32, row: List[Option[String]]): Result[String, Bool] =
        forM(
            cell  <- text(index, row);
            value <- match cell {
                case "t" => Ok(true)
                case "f" => Ok(false)
                case _   => Err("column ${index} is not a boolean: \"${cell}\"")
            }
        ) yield value

    /// An `int[]` column arrives as the array literal it was written as.
    pub def optionalIntArray(index: Int32, row: List[Option[String]]): Result[String, Option[List[Option[Int32]]]] =
        match optionalText(index, row) {
            case Err(cause)     => Err(cause)
            case Ok(None)       => Ok(None)
            case Ok(Some(cell)) => parseArray(index, cell) |> Result.map(values -> Some(values))
        }

    def parseArray(index: Int32, cell: String): Result[String, List[Option[Int32]]] =
        match String.stripPrefix({substr = "{"}, cell) |> Option.flatMap(String.stripSuffix({substr = "}"})) {
            case None       => Err("column ${index} is not an array literal: \"${cell}\"")
            case Some("")   => Ok(Nil)
            case Some(body) =>
                String.splitOn({substr = ","}, body) |> Result.traverse(element -> match element {
                    case "NULL" => Ok(None)
                    case value  => parse(index, value) |> Result.map(n -> Some(n))
                })
        }

    pub def expect(message: String, value: Option[a]): Result[String, a] =
        match value {
            case Some(x) => Ok(x)
            case None    => Err(message)
        }

}
