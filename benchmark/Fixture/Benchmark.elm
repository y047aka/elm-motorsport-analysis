module Fixture.Benchmark exposing (main)

import Benchmark exposing (Benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Fixture.Csv as Fixture
import Fixture.Json as Fixture


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    describe "Fixture" <|
        [ Benchmark.compare "xxxDecoded"
            "csvDecoded"
            -- 289,888,583 runs/s (GoF: 99.92%)
            (\_ -> Fixture.csvDecoded)
            "jsonDecoded"
            -- 289,947,739 runs/s (GoF: 99.98%)
            (\_ -> Fixture.jsonDecoded)
        , Benchmark.scale "csvDecodedOfSize"
            ([--    5 -- 63,654,091 runs/s (GoF: 99.99%)
              --  , 50 -- 6,706,644 runs/s (GoF: 99.99%)
              --  , 500 -- 61,496 runs/s (GoF: 99.94%)
              --  , 5000 -- 21,782 runs/s (GoF: 99.98%)
             ]
                |> List.map (\size -> ( toString size, \_ -> Fixture.csvDecodedOfSize size ))
            )
        , Benchmark.scale "jsonDecodedOfSize"
            ([--    5 -- 63,155,588 runs/s (GoF: 100%)
              --  , 50 -- 6,668,796 runs/s (GoF: 99.99%)
              --  , 500 -- 62,312 runs/s (GoF: 99.96%)
              --  , 5000 -- 21,906 runs/s (GoF: 99.99%)
             ]
                |> List.map (\size -> ( toString size, \_ -> Fixture.jsonDecodedOfSize size ))
            )
        ]


toString : Int -> String
toString n =
    "n = " ++ String.fromInt n
