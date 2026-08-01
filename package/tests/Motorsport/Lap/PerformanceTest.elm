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
                    rate { time = 5000, personalBest = 5000, fastest = 5000 }
                        |> Expect.equal Fastest
            , test "matching the car's own best, but not the race's, is a personal best" <|
                \_ ->
                    rate { time = 6000, personalBest = 6000, fastest = 5000 }
                        |> Expect.equal PersonalBest
            , test "beating neither is standard" <|
                \_ ->
                    rate { time = 7000, personalBest = 6000, fastest = 5000 }
                        |> Expect.equal Standard
            , test "a time the data did not record takes no colour" <|
                -- Zero is how an unrecorded time arrives, and how a record no
                -- lap has set yet reads back (whether that's the race's
                -- baseline or the car's own personal best). Left to match, it
                -- would rate as the fastest of the race, or as the car's own
                -- best.
                \_ ->
                    rate { time = 0, personalBest = 0, fastest = 0 }
                        |> Expect.equal Standard
            ]
        ]


rate : { time : Duration, personalBest : Duration, fastest : Duration } -> PerformanceLevel
rate =
    Performance.performanceLevel
