module Array.Extra2.Benchmark exposing (main)

import Array.Extra2
import Benchmark exposing (Benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Fixture
import List.Extra


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    describe "Array.Extra2" <|
        [ Benchmark.compare "find"
            "List.Extra.find"
            (\_ ->
                -- 21,632,561 runs/s (GoF: 99.96%)
                List.Extra.find (.lapNumber >> (==) 2) Fixture.csvDecoded
            )
            "Array.Extra2.find"
            (\_ ->
                -- 107,375 runs/s (GoF: 99.87%)
                Array.Extra2.find (.lapNumber >> (==) 2) Fixture.csvDecoded_array
            )
        , Benchmark.compare "find"
            "List.Extra.find"
            (\_ ->
                -- 307,584 runs/s (GoF: 99.99%)
                List.Extra.find (.lapNumber >> (==) 200) Fixture.csvDecoded
            )
            "Array.Extra2.find"
            (\_ ->
                -- 86,520 runs/s (GoF: 99.96%)
                Array.Extra2.find (.lapNumber >> (==) 200) Fixture.csvDecoded_array
            )
        ]
