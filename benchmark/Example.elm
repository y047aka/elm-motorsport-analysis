module Example exposing (dict, main, match)

import Benchmark exposing (Benchmark, benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Dict
import Regex exposing (Regex)


main : BenchmarkProgram
main =
    program <|
        describe "sample"
            [ dict
            , match
            ]


dict : Benchmark
dict =
    let
        dest =
            Dict.singleton "a" 1
    in
    describe "dictionary"
        [ benchmark "get" (\_ -> Dict.get "a" dest)
        , benchmark "insert" (\_ -> Dict.insert "b" 2 dest)
        ]


regex : Regex
regex =
    Regex.fromString "^a+"
        |> Maybe.withDefault Regex.never


match : Benchmark
match =
    benchmark "regex match" <|
        \_ ->
            Regex.contains regex
                "aaaaaaaaaaaaaaaaaaaaaaaaaa"
