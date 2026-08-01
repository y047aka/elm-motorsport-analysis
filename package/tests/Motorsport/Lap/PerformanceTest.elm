module Motorsport.Lap.PerformanceTest exposing (suite)

import Expect
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap.Performance as Performance exposing (PerformanceLevel(..))
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Motorsport.Lap.Performance"
        [ describe "performanceLevel"
            [ test "matching the race's fastest is the fastest" <|
                \_ ->
                    rate { time = 5000, personalBest = Just 5000, fastest = Just 5000 }
                        |> Expect.equal Fastest
            , test "matching the car's own best, but not the race's, is a personal best" <|
                \_ ->
                    rate { time = 6000, personalBest = Just 6000, fastest = Just 5000 }
                        |> Expect.equal PersonalBest
            , test "beating neither is standard" <|
                \_ ->
                    rate { time = 7000, personalBest = Just 6000, fastest = Just 5000 }
                        |> Expect.equal Standard
            , test "a baseline no lap has set yet matches nothing" <|
                -- Nothing has beaten a record that has not been set. This used
                -- to need a guard of its own: an unset baseline read back as a
                -- zero, and so rated every unrecorded time as the fastest of
                -- the race until the first real one was set.
                \_ ->
                    rate { time = 5000, personalBest = Nothing, fastest = Nothing }
                        |> Expect.equal Standard
            ]
        ]


rate : { time : Duration, personalBest : Maybe Duration, fastest : Maybe Duration } -> PerformanceLevel
rate =
    Performance.performanceLevel
