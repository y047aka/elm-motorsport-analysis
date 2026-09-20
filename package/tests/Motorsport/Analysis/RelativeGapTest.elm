module Motorsport.Analysis.RelativeGapTest exposing (suite)

import Expect
import Motorsport.Analysis.RelativeGap as RelativeGap
import Motorsport.Duration exposing (Duration)
import Motorsport.Instant as Instant
import Motorsport.Lap as Lap exposing (Lap)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Motorsport.Analysis.RelativeGap"
        [ describe "a car is measured against where the group was on the lap it ran"
            [ test "the quicker of two cars has time in hand, which reads below the group" <|
                \_ ->
                    -- The group crossed lap 1 at 101.000 on average.
                    gapsOf [ crossing 1 100000, crossing 1 102000 ] [ crossing 1 100000 ]
                        |> Expect.equal [ { lap = 1, gap = -1000 } ]
            , test "and the slower one has lost that much, which reads above it" <|
                \_ ->
                    gapsOf [ crossing 1 100000, crossing 1 102000 ] [ crossing 1 102000 ]
                        |> Expect.equal [ { lap = 1, gap = 1000 } ]
            , test "each lap is averaged on its own, so a car is not measured against another lap" <|
                \_ ->
                    gapsOf
                        [ crossing 1 100000, crossing 1 102000, crossing 2 200000, crossing 2 206000 ]
                        [ crossing 1 100000, crossing 2 200000 ]
                        |> Expect.equal [ { lap = 1, gap = -1000 }, { lap = 2, gap = -3000 } ]
            , test "a lap the group never ran is a lap with nothing to measure against" <|
                \_ ->
                    gapsOf [ crossing 1 100000 ] [ crossing 2 200000 ]
                        |> Expect.equal []
            ]
        , describe "what the group is taken over"
            [ test "a lap that touched the pit lane says nothing about where the group was" <|
                \_ ->
                    -- Averaged in, the stop would drag the baseline out to
                    -- 120.666 and the gap with it.
                    gapsOf
                        [ crossing 1 100000, crossing 1 102000, stopping 1 160000 ]
                        [ crossing 1 100000 ]
                        |> Expect.equal [ { lap = 1, gap = -1000 } ]
            , test "the mean is whole milliseconds, the remainder dropped" <|
                \_ ->
                    -- 1.000 and 1.001 average to 1.000, not to 1.0005.
                    gapsOf [ crossing 1 1000, crossing 1 1001 ] [ crossing 1 1001 ]
                        |> Expect.equal [ { lap = 1, gap = 1 } ]
            ]
        , describe "a group with no lap to be read off"
            [ test "a group that never left the pit lane is no baseline at all" <|
                \_ ->
                    RelativeGap.baseline [ stopping 1 100000 ]
                        |> RelativeGap.isEmpty
                        |> Expect.equal True
            , test "one racing lap is enough to be one" <|
                \_ ->
                    RelativeGap.baseline [ crossing 1 100000 ]
                        |> RelativeGap.isEmpty
                        |> Expect.equal False
            ]
        ]



-- FIXTURE


{-| The group's laps, then the car's, as the two views hand them over.
-}
gapsOf : List Lap -> List Lap -> List RelativeGap.Point
gapsOf groupLaps carLaps =
    RelativeGap.against (RelativeGap.baseline groupLaps) carLaps


{-| A lap completed on the road at `elapsed`. Only the lap number and the moment
it ended are read here.
-}
crossing : Int -> Duration -> Lap
crossing lapNumber elapsed =
    { emptyLap | lap = lapNumber, elapsed = Instant.fromDuration elapsed }


{-| The same lap, ended in the pit lane.
-}
stopping : Int -> Duration -> Lap
stopping lapNumber elapsed =
    { emptyLap | lap = lapNumber, elapsed = Instant.fromDuration elapsed, pit = Lap.InLap }


emptyLap : Lap
emptyLap =
    Lap.empty
