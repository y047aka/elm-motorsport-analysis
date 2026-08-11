mod Util.Json.TestEncodeExtra {

    use Util.Json.Encode
    use Util.Json.Encode.Extra
    use Util.Json.Encode.JsonValue.{JsonNull, JsonInt, JsonString, JsonArray, JsonObject}

    @Test
    def testRenderScalar(): Unit \ Assert =
        Assert.assertTrue(Extra.render(JsonString("hello")) == "\"hello\"")

    @Test
    def testRenderEmptyObject(): Unit \ Assert =
        Assert.assertTrue(Extra.render(JsonObject(Nil)) == "{}")

    @Test
    def testSinglePropertyObjectIsInline(): Unit \ Assert =
        let obj = JsonObject(("name", JsonString("James CALADO")) :: Nil);
        Assert.assertTrue(Extra.render(obj) == "{ \"name\": \"James CALADO\" }")

    @Test
    def testSinglePropertyObjectWithNullIsInline(): Unit \ Assert =
        Assert.assertTrue(Extra.render(JsonObject(("value", JsonNull) :: Nil)) == "{ \"value\": null }")

    @Test
    def testSinglePropertyObjectWithEmptyArrayIsInline(): Unit \ Assert =
        Assert.assertTrue(Extra.render(JsonObject(("drivers", JsonArray(Nil)) :: Nil)) == "{ \"drivers\": [] }")

    @Test
    def testNestedSinglePropertyObjectsCollapseTogether(): Unit \ Assert =
        let obj = JsonObject(("car", JsonObject(("number", JsonString("7")) :: Nil)) :: Nil);
        Assert.assertTrue(Extra.render(obj) == "{ \"car\": { \"number\": \"7\" } }")

    @Test
    def testSinglePropertyObjectWithMultiLineValueIsNotInline(): Unit \ Assert =
        let obj = JsonObject(("drivers", JsonArray(JsonString("a") :: JsonString("b") :: Nil)) :: Nil);
        Assert.assertTrue(Extra.render(obj) == "{\n  \"drivers\": [\n    \"a\",\n    \"b\"\n  ]\n}")

    @Test
    def testTwoPropertyObjectIsNotInline(): Unit \ Assert =
        let obj = JsonObject(("time", JsonString("20.708")) :: ("elapsed", JsonString("20.708")) :: Nil);
        Assert.assertTrue(Extra.render(obj) == "{\n  \"time\": \"20.708\",\n  \"elapsed\": \"20.708\"\n}")

    @Test
    def testInlineObjectKeepsItsIndentInsideAnArray(): Unit \ Assert =
        let arr = JsonArray(JsonObject(("name", JsonString("Alex LYNN")) :: Nil) :: Nil);
        Assert.assertTrue(Extra.render(arr) == "[\n  { \"name\": \"Alex LYNN\" }\n]")

    @Test
    def testKeyIsEscaped(): Unit \ Assert =
        let obj = JsonObject(("say \"hi\"", JsonInt(1)) :: Nil);
        Assert.assertTrue(Extra.render(obj) == "{ \"say \\\"hi\\\"\": 1 }")

    @Test
    def testMultiPropertyObjectMatchesEncode(): Unit \ Assert =
        let obj = JsonObject(
            ("name", JsonString("test")) ::
            ("laps", JsonArray(JsonInt(1) :: JsonInt(2) :: Nil)) ::
            Nil
        );
        Assert.assertTrue(Extra.render(obj) == Encode.render(obj))

}
