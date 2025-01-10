module DecoderTest exposing (suite)

import Expect
import Fixture.Csv
import Fixture.Json.Laps
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Decoder tests"
        [ test "jsonDecoded and csvDecoded" <|
            \_ ->
                Fixture.Json.Laps.jsonDecoded
                    |> Expect.equal Fixture.Csv.csvDecoded
        ]
