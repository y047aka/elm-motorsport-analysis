mod Util.TestJson {

    use Util.Json.Encode
    use Util.Json.Encode.JsonValue.{JsonNull, JsonBool, JsonInt, JsonFloat, JsonString, JsonArray, JsonObject}

    @Test
    def testRenderNull(): Unit \ Assert =
        Assert.assertTrue(Encode.render(JsonNull) == "null")

    @Test
    def testRenderBoolTrue(): Unit \ Assert =
        Assert.assertTrue(Encode.render(JsonBool(true)) == "true")

    @Test
    def testRenderBoolFalse(): Unit \ Assert =
        Assert.assertTrue(Encode.render(JsonBool(false)) == "false")

    @Test
    def testRenderInt(): Unit \ Assert =
        Assert.assertTrue(Encode.render(JsonInt(42)) == "42")

    @Test
    def testRenderString(): Unit \ Assert =
        Assert.assertTrue(Encode.render(JsonString("hello")) == "\"hello\"")

    @Test
    def testRenderStringWithQuotes(): Unit \ Assert =
        let result = Encode.render(JsonString("say \"hi\""));
        Assert.assertTrue(String.contains({substr = "\\\""}, result))

    @Test
    def testRenderEmptyArray(): Unit \ Assert =
        Assert.assertTrue(Encode.render(JsonArray(Nil)) == "[]")

    @Test
    def testRenderEmptyObject(): Unit \ Assert =
        Assert.assertTrue(Encode.render(JsonObject(Nil)) == "{}")

    @Test
    def testRenderObject(): Unit \ Assert =
        let obj = JsonObject(("name", JsonString("test")) :: ("value", JsonInt(1)) :: Nil);
        let result = Encode.render(obj);
        Assert.assertTrue(String.contains({substr = "\"name\": \"test\""}, result));
        Assert.assertTrue(String.contains({substr = "\"value\": 1"}, result))

    @Test
    def testRenderArray(): Unit \ Assert =
        let arr = JsonArray(JsonInt(1) :: JsonInt(2) :: Nil);
        let result = Encode.render(arr);
        Assert.assertTrue(String.contains({substr = "1"}, result));
        Assert.assertTrue(String.contains({substr = "2"}, result))

}
