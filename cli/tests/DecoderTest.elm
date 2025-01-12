module DecoderTest exposing (suite)

import Data_Cli.Wec.Preprocess
import Expect
import Fixture.Csv
import Fixture.Json
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Decoder tests"
        [ test "jsonDecoded and csvDecoded" <|
            \_ ->
                -- CSVデコードと、それを元にしたJSONデコードで同じ結果が得られることを確認
                (Fixture.Json.jsonDecoded |> .laps)
                    |> Expect.equal Fixture.Csv.csvDecoded
        , test "jsonDecoded and preprocessed" <|
            \_ ->
                -- CLIでの前処理と、それを元にしたJSONデコードで同じ結果が得られることを確認
                (Fixture.Json.jsonDecoded |> .preprocessed)
                    |> Expect.equal (Data_Cli.Wec.Preprocess.preprocess { laps = Fixture.Csv.csvDecoded })
        ]
