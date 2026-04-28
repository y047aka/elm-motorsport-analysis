pub mod Util.Csv {

    pub type alias CsvRow = List[String]

    pub def parseRow(line: String): CsvRow =
        String.split({regex = ";"}, line)

    pub def parse(lines: List[String]): List[CsvRow] =
        lines |> List.map(parseRow)

}
