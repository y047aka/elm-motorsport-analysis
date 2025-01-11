module DecoderTest exposing (suite)

import Data.Wec.Preprocess
import Expect
import Fixture.Csv
import Fixture.Json
import Fixture.Json.Laps
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Decoder tests"
        [ test "jsonDecoded and csvDecoded" <|
            \_ ->
                Fixture.Json.Laps.jsonDecoded
                    |> Expect.equal Fixture.Csv.csvDecoded
        , test "jsonDecoded and preprocessed" <|
            \_ ->
                -- CLIでの前処理と、それを元にしたJSONデコードで同じ結果が得られることを確認
                (Fixture.Json.jsonDecoded |> .preprocessed)
                    |> Expect.equal (Data.Wec.Preprocess.preprocess { laps = Fixture.Csv.csvDecoded })
        ]
