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
    def testTwoPropertyObjectIsInline(): Unit \ Assert =
        let obj = JsonObject(("time", JsonString("20.708")) :: ("elapsed", JsonString("20.708")) :: Nil);
        Assert.assertTrue(Extra.render(obj) == "{ \"time\": \"20.708\", \"elapsed\": \"20.708\" }")

    @Test
    def testTwoPropertyObjectWithOneMultiLineValueIsNotInline(): Unit \ Assert =
        let obj = JsonObject(
            ("name", JsonString("test")) ::
            ("laps", JsonArray(JsonInt(1) :: JsonInt(2) :: Nil)) ::
            Nil
        );
        Assert.assertTrue(Extra.render(obj) == "{\n  \"name\": \"test\",\n  \"laps\": [\n    1,\n    2\n  ]\n}")

    @Test
    def testThreePropertyObjectIsNotInline(): Unit \ Assert =
        let obj = JsonObject(
            ("s1", JsonString("51.908")) ::
            ("s2", JsonString("1:23.252")) ::
            ("s3", JsonString("1:39.395")) ::
            Nil
        );
        Assert.assertTrue(Extra.render(obj) == "{\n  \"s1\": \"51.908\",\n  \"s2\": \"1:23.252\",\n  \"s3\": \"1:39.395\"\n}")

    @Test
    def testInlineObjectKeepsItsIndentInsideAnArray(): Unit \ Assert =
        let arr = JsonArray(JsonObject(("name", JsonString("Alex LYNN")) :: Nil) :: Nil);
        Assert.assertTrue(Extra.render(arr) == "[\n  { \"name\": \"Alex LYNN\" }\n]")

    @Test
    def testInlineObjectKeepsItsIndentAsAProperty(): Unit \ Assert =
        let obj = JsonObject(
            ("scl2", JsonObject(("time", JsonString("20.708")) :: ("elapsed", JsonString("20.708")) :: Nil)) ::
            ("z4",   JsonObject(("time", JsonString("13.826")) :: ("elapsed", JsonString("34.534")) :: Nil)) ::
            ("ip1",  JsonObject(("time", JsonString("17.374")) :: ("elapsed", JsonString("51.908")) :: Nil)) ::
            Nil
        );
        Assert.assertTrue(Extra.render(obj) == List.join("\n",
            "{" ::
            "  \"scl2\": { \"time\": \"20.708\", \"elapsed\": \"20.708\" }," ::
            "  \"z4\": { \"time\": \"13.826\", \"elapsed\": \"34.534\" }," ::
            "  \"ip1\": { \"time\": \"17.374\", \"elapsed\": \"51.908\" }" ::
            "}" :: Nil
        ))

    @Test
    def testKeyIsEscaped(): Unit \ Assert =
        let obj = JsonObject(("say \"hi\"", JsonInt(1)) :: Nil);
        Assert.assertTrue(Extra.render(obj) == "{ \"say \\\"hi\\\"\": 1 }")

    @Test
    def testExpandedObjectMatchesEncode(): Unit \ Assert =
        let obj = JsonObject(
            ("name", JsonString("test")) ::
            ("season", JsonInt(2025)) ::
            ("laps", JsonArray(JsonInt(1) :: JsonInt(2) :: Nil)) ::
            Nil
        );
        Assert.assertTrue(Extra.render(obj) == Encode.render(obj))

}
