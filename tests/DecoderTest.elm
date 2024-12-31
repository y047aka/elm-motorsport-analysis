module DecoderTest exposing (suite)

import Expect
import Fixture
import Fixture.Json
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Decoder tests"
        [ test "jsonDecoded and csvDecoded" <|
            \_ ->
                Fixture.Json.jsonDecoded
                    |> Expect.equal Fixture.csvDecoded
        ]
