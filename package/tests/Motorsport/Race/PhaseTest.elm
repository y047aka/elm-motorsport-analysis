module Motorsport.Race.PhaseTest exposing (suite)

import Expect
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Race.Phase as Phase exposing (Phase(..))
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Phase.at"
        [ describe "a race that ran its full time"
            -- The flag falls at 100.000 on a lap already under way, and the
            -- last car is round at 110.000.
            [ test "reads the race out in three parts" <|
                \_ ->
                    [ 0, 99999, 100000, 109999, 110000, 200000 ]
                        |> List.map (phaseOf { timeLimit = 100000, finishedAt = 110000 })
                        |> Expect.equalLists
                            [ Running, Running, Finishing, Finishing, Over, Over ]
            ]
        , describe "a race stopped before its time limit"
            -- Nothing says the two are the other way round, and a shortened
            -- race is the case that says so.
            [ test "is over at the last crossing, whatever the limit says" <|
                \_ ->
                    [ 0, 69999, 70000, 100000, 200000 ]
                        |> List.map (phaseOf { timeLimit = 100000, finishedAt = 70000 })
                        |> Expect.equalLists
                            [ Running, Running, Over, Over, Over ]
            , test "never reaches Finishing, having had no laps under the flag" <|
                \_ ->
                    List.range 0 20
                        |> List.map (\n -> phaseOf { timeLimit = 100000, finishedAt = 70000 } (n * 10000))
                        |> List.member Finishing
                        |> Expect.equal False
            ]
        , describe "a race with nothing in it"
            [ test "is over from the start" <|
                \_ ->
                    phaseOf { timeLimit = 0, finishedAt = 0 } 0
                        |> Expect.equal Over
            ]
        ]


phaseOf : { timeLimit : Int, finishedAt : Int } -> Int -> Phase
phaseOf ends elapsed =
    Phase.at { elapsed = instant elapsed }
        { timeLimit = instant ends.timeLimit
        , finishedAt = instant ends.finishedAt
        }


instant : Int -> Instant
instant =
    Instant.fromDuration
