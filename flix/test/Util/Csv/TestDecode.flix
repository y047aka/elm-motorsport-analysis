mod Util.Csv.TestDecode {

    use Util.Csv.Decode
    use Util.Csv.Decode.{Decoder, FieldNames, Error, DecodingError, Column, Problem}

    @Test
    def testColumnString(): Unit \ Assert =
        let d = Decode.column(0, Decode.string());
        match Decode.decodeCsv(FieldNames.NoFieldNames, d, "hello") {
            case Ok(xs) => Assert.assertTrue(xs == "hello" :: Nil)
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testColumnInt(): Unit \ Assert =
        let d = Decode.column(0, Decode.int());
        match Decode.decodeCsv(FieldNames.NoFieldNames, d, "42\n7") {
            case Ok(xs) => Assert.assertTrue(xs == 42 :: 7 :: Nil)
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testColumnOutOfRange(): Unit \ Assert =
        let d = Decode.column(5, Decode.string());
        match Decode.decodeCsv(FieldNames.NoFieldNames, d, "a,b,c") {
            case Err(Error.DecodingErrors(es)) =>
                match List.head(es) {
                    case Some(DecodingError.FieldDecodingError(_, _, Problem.ColumnNotFound(5))) => Assert.assertTrue(true)
                    case _ => Assert.assertTrue(false)
                }
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testIntFailureCarriesRawCell(): Unit \ Assert =
        let d = Decode.column(0, Decode.int());
        match Decode.decodeCsv(FieldNames.NoFieldNames, d, "abc") {
            case Err(Error.DecodingErrors(es)) =>
                match List.head(es) {
                    case Some(DecodingError.FieldDecodingError(_, _, Problem.ExpectedInt("abc"))) => Assert.assertTrue(true)
                    case _ => Assert.assertTrue(false)
                }
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testFieldByHeader(): Unit \ Assert =
        let d = Decode.field("name", Decode.string());
        let csv = "id,name\n1,Alice\n2,Bob";
        match Decode.decodeCsv(FieldNames.FieldNamesFromFirstRow, d, csv) {
            case Ok(xs) => Assert.assertTrue(xs == "Alice" :: "Bob" :: Nil)
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testFieldNotFound(): Unit \ Assert =
        let d = Decode.field("missing", Decode.string());
        match Decode.decodeCsv(FieldNames.FieldNamesFromFirstRow, d, "id,name\n1,Alice") {
            case Err(Error.DecodingErrors(es)) =>
                match List.head(es) {
                    case Some(DecodingError.FieldNotProvided("missing")) => Assert.assertTrue(true)
                    case _ => Assert.assertTrue(false)
                }
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testCustomFieldNames(): Unit \ Assert =
        let d = Decode.field("age", Decode.int());
        let names = FieldNames.CustomFieldNames("name" :: "age" :: Nil);
        match Decode.decodeCsv(names, d, "Alice,30\nBob,25") {
            case Ok(xs) => Assert.assertTrue(xs == 30 :: 25 :: Nil)
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testNoFieldNamesOnFirstRow(): Unit \ Assert =
        let d = Decode.field("name", Decode.string());
        match Decode.decodeCsv(FieldNames.FieldNamesFromFirstRow, d, "") {
            case Err(Error.NoFieldNamesOnFirstRow) => Assert.assertTrue(true)
            case _                                  => Assert.assertTrue(false)
        }

    @Test
    def testIntoRecordPipeline(): Unit \ Assert =
        let d =
            Decode.intoRecord((name, age) -> {name = name, age = age})
                |> Decode.pipeline(Decode.column(0, Decode.string()))
                |> Decode.pipeline(Decode.column(1, Decode.int()));
        match Decode.decodeCsv(FieldNames.NoFieldNames, d, "Alice,30\nBob,25") {
            case Ok(xs) =>
                Assert.assertTrue(List.length(xs) == 2);
                match List.head(xs) {
                    case Some(r) =>
                        Assert.assertTrue(r#name == "Alice");
                        Assert.assertTrue(r#age == 30)
                    case None => Assert.assertTrue(false)
                }
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testOneOfFallsThrough(): Unit \ Assert =
        let d = Decode.oneOf(Decode.column(0, Decode.int()), Decode.succeed(0) :: Nil);
        match Decode.decodeCsv(FieldNames.NoFieldNames, d, "abc") {
            case Ok(xs) => Assert.assertTrue(xs == 0 :: Nil)
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testOneOfAllFail(): Unit \ Assert =
        let d = Decode.oneOf(Decode.column(0, Decode.int()),
                             Decode.column(0, Decode.float()) |> Decode.map(_ -> 0) :: Nil);
        match Decode.decodeCsv(FieldNames.NoFieldNames, d, "abc") {
            case Err(Error.DecodingErrors(es)) =>
                match List.head(es) {
                    case Some(DecodingError.OneOfDecodingError(_, sub)) =>
                        Assert.assertTrue(List.length(sub) == 2)
                    case _ => Assert.assertTrue(false)
                }
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testBlankReturnsNoneForEmptyCell(): Unit \ Assert =
        let d = Decode.column(1, Decode.blank(Decode.int()));
        match Decode.decodeCsv(FieldNames.NoFieldNames, d, "a,,c") {
            case Ok(xs) => Assert.assertTrue(xs == None :: Nil)
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testBlankReturnsSomeForFilledCell(): Unit \ Assert =
        let d = Decode.column(1, Decode.blank(Decode.int()));
        match Decode.decodeCsv(FieldNames.NoFieldNames, d, "a,42,c") {
            case Ok(xs) => Assert.assertTrue(xs == Some(42) :: Nil)
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testOptionalColumnOutOfRange(): Unit \ Assert =
        let d = Decode.optionalColumn(99, Decode.string());
        match Decode.decodeCsv(FieldNames.NoFieldNames, d, "a,b,c") {
            case Ok(xs) => Assert.assertTrue(xs == None :: Nil)
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testOptionalFieldAbsent(): Unit \ Assert =
        let d = Decode.optionalField("missing", Decode.string());
        match Decode.decodeCsv(FieldNames.FieldNamesFromFirstRow, d, "id,name\n1,Alice") {
            case Ok(xs) => Assert.assertTrue(xs == None :: Nil)
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testAndThenSwitchesDecoder(): Unit \ Assert =
        // First column says which kind we want, second column is the value.
        let d =
            Decode.column(0, Decode.string()) |> Decode.andThen(kind ->
                if (kind == "int")
                    Decode.column(1, Decode.int()) |> Decode.map(n -> "int=${n}")
                else
                    Decode.column(1, Decode.string()) |> Decode.map(s -> "str=${s}")
            );
        match Decode.decodeCsv(FieldNames.NoFieldNames, d, "int,42\nstr,hello") {
            case Ok(xs) => Assert.assertTrue(xs == "int=42" :: "str=hello" :: Nil)
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testFromResultOk(): Unit \ Assert =
        let d: Decoder[Int32] = Decode.fromResult(Ok(7));
        match Decode.decodeCsv(FieldNames.NoFieldNames, d, "anything") {
            case Ok(xs) => Assert.assertTrue(xs == 7 :: Nil)
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testFromMaybeNone(): Unit \ Assert =
        let d: Decoder[Int32] = Decode.fromMaybe("missing!", None);
        match Decode.decodeCsv(FieldNames.NoFieldNames, d, "anything") {
            case Err(Error.DecodingErrors(es)) =>
                match List.head(es) {
                    case Some(DecodingError.FieldDecodingError(_, _, Problem.Failure("missing!"))) => Assert.assertTrue(true)
                    case _ => Assert.assertTrue(false)
                }
            case _ => Assert.assertTrue(false)
        }

    @Test
    def testDecodeCustomSemicolonSeparator(): Unit \ Assert =
        let d = Decode.column(2, Decode.string());
        match Decode.decodeCustom({fieldSeparator = ';'}, FieldNames.NoFieldNames, d, "a;b;c\nd;e;f") {
            case Ok(xs) => Assert.assertTrue(xs == "c" :: "f" :: Nil)
            case Err(_) => Assert.assertTrue(false)
        }

    @Test
    def testErrorToStringMentionsRowAndColumn(): Unit \ Assert =
        let d = Decode.column(0, Decode.int());
        match Decode.decodeCsv(FieldNames.NoFieldNames, d, "abc") {
            case Err(e) =>
                let msg = Decode.errorToString(e);
                Assert.assertTrue(String.contains({substr = "row 0"}, msg));
                Assert.assertTrue(String.contains({substr = "column 0"}, msg));
                Assert.assertTrue(String.contains({substr = "could not parse an int"}, msg))
            case Ok(_) => Assert.assertTrue(false)
        }

    @Test
    def testParsingErrorPropagated(): Unit \ Assert =
        let d = Decode.column(0, Decode.string());
        match Decode.decodeCsv(FieldNames.NoFieldNames, d, "\"unterminated") {
            case Err(Error.ParsingError(_)) => Assert.assertTrue(true)
            case _                          => Assert.assertTrue(false)
        }

    @Test
    def testAvailableFields(): Unit \ Assert =
        let d = Decode.availableFields();
        match Decode.decodeCsv(FieldNames.FieldNamesFromFirstRow, d, "id,name,age\n1,A,2") {
            case Ok(xs) =>
                match List.head(xs) {
                    case Some(fields) =>
                        Assert.assertTrue(List.memberOf("id", fields));
                        Assert.assertTrue(List.memberOf("name", fields));
                        Assert.assertTrue(List.memberOf("age", fields))
                    case None => Assert.assertTrue(false)
                }
            case Err(_) => Assert.assertTrue(false)
        }

}
