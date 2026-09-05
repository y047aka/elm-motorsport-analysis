/// Reading one row of a `Db.fetch` result. Every cell arrives as text, or
/// as nothing where the column was null, so what a query means is settled here
/// beside the query rather than at the boundary.
mod Db.Row {

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

    /// A truth value is stored as the 1 or 0 the driver bound it as.
    pub def bool(index: Int32, row: List[Option[String]]): Result[String, Bool] =
        forM(
            cell  <- text(index, row);
            value <- match cell {
                case "1" => Ok(true)
                case "0" => Ok(false)
                case _   => Err("column ${index} is not a boolean: \"${cell}\"")
            }
        ) yield value

    /// A mini-sector column arrives as the JSON array it was written as.
    pub def optionalIntArray(index: Int32, row: List[Option[String]]): Result[String, Option[List[Option[Int32]]]] =
        match optionalText(index, row) {
            case Err(cause)     => Err(cause)
            case Ok(None)       => Ok(None)
            case Ok(Some(cell)) => parseArray(index, cell) |> Result.map(values -> Some(values))
        }

    def parseArray(index: Int32, cell: String): Result[String, List[Option[Int32]]] =
        match String.stripPrefix({substr = "["}, cell) |> Option.flatMap(String.stripSuffix({substr = "]"})) {
            case None       => Err("column ${index} is not a JSON array: \"${cell}\"")
            case Some("")   => Ok(Nil)
            case Some(body) =>
                String.splitOn({substr = ","}, body) |> Result.traverse(element -> match element {
                    case "null" => Ok(None)
                    case value  => parse(index, value) |> Result.map(n -> Some(n))
                })
        }

    pub def expect(message: String, value: Option[a]): Result[String, a] =
        match value {
            case Some(x) => Ok(x)
            case None    => Err(message)
        }

}
