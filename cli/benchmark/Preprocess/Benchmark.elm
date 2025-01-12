module Preprocess.Benchmark exposing (main)

import AssocList
import AssocList.Extra
import Benchmark exposing (Benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Data.Wec.Decoder as Wec
import Data_Cli.Wec.Preprocess as Preprocess_Wec
import Fixture.Csv as Fixture
import Motorsport.Car exposing (Car)
import Preprocess.Helper.Benchmark exposing (preprocess_deprecated)


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    describe "Data.Wec.Preprocess.preprocess"
        [ Benchmark.scale "old"
            ([ 10 -- 67,307 runs/s (GoF: 99.99%)
             , 100 -- 1,272 runs/s (GoF: 99.99%)

             --  , 1000 -- 62 runs/s (GoF: 99.99%)
             --  , 5000 -- 11 runs/s (GoF: 100%)
             ]
                |> List.map (\size -> ( size, Fixture.csvDecodedOfSize size ))
                |> List.map (\( size, target ) -> ( toString size, \_ -> deprecated target ))
            )
        , Benchmark.scale "improved"
            ([ 10 -- 110,453 runs/s (GoF: 99.99%)
             , 100 -- 5,921 runs/s (GoF: 99.99%)
             , 1000 -- 379 runs/s (GoF: 99.99%)

             --  , 5000 -- 71 runs/s (GoF: 100%)
             ]
                |> List.map (\size -> ( size, Fixture.csvDecodedOfSize size ))
                |> List.map (\( size, target ) -> ( toString size, \_ -> Preprocess_Wec.preprocess { laps = target } ))
            )
        ]


toString : Int -> String
toString n =
    "n = " ++ String.fromInt n


deprecated : List Wec.Lap -> List Car
deprecated laps =
    let
        startPositions =
            List.filter (\{ lapNumber } -> lapNumber == 1) laps
                |> List.sortBy .elapsed
                |> List.map .carNumber

        ordersByLap =
            laps
                |> AssocList.Extra.groupBy .lapNumber
                |> AssocList.toList
                |> List.map
                    (\( lapNumber, cars ) ->
                        { lapNumber = lapNumber
                        , order = cars |> List.sortBy .elapsed |> List.map .carNumber
                        }
                    )
    in
    laps
        |> AssocList.Extra.groupBy .carNumber
        |> AssocList.toList
        |> List.map
            (\( carNumber, laps__ ) ->
                preprocess_deprecated
                    { carNumber = carNumber
                    , laps = laps__
                    , startPositions = startPositions
                    , ordersByLap = ordersByLap
                    }
            )
