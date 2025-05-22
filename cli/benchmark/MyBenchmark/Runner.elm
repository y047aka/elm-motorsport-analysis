module MyBenchmark.Runner exposing (program, BenchmarkProgram)

{-| Browser Benchmark Runner

@docs program, BenchmarkProgram

-}

import Browser
import Html
import MyBenchmark as Benchmark exposing (Benchmark)
import MyBenchmark.Runner.App as App exposing (Model, Msg)


{-| A handy type alias for values produced by [`program`](#program)
-}
type alias BenchmarkProgram =
    Program () Model Msg


{-| Create a runner program from a benchmark. For example:

    main : BenchmarkProgram
    main =
        Runner.program <|
            Benchmark.describe "your benchmarks"
                [{- your benchmarks here -}]

Compile this and visit the result in your browser to run the
benchmarks.

-}
program : Benchmark -> BenchmarkProgram
program benchmark =
    Browser.element
        { init = App.init benchmark
        , update = App.update
        , view = App.view
        , subscriptions = always Sub.none
        }
