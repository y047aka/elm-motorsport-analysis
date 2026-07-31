module Motorsport.LapTest exposing (tests)

import Expect
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Sector as Sector exposing (Sector(..))
import Test exposing (..)


{-| A lap running from 4.000 to 10.000, split 1.000 / 2.000 / 3.000.
-}
lap : Lap
lap =
    { empty
        | time = 6000
        , elapsed = 10000
        , sectors =
            { s1 = { time = 1000, personalBest = 0 }
            , s2 = { time = 2000, personalBest = 0 }
            , s3 = { time = 3000, personalBest = 0 }
            }
    }


empty : Lap
empty =
    Lap.empty


tests : Test
tests =
    describe "Motorsport.Lap"
        [ describe "segments"
            [ test "starts each sector where the one before it ended" <|
                \_ ->
                    Lap.segments lap
                        |> Sector.values
                        |> List.map .start
                        |> Expect.equal [ 4000, 5000, 7000 ]
            , test "measures the first sector from the start of the lap, not the previous lap record" <|
                \_ ->
                    (Lap.segments lap).s1.start
                        |> Expect.equal (lap.elapsed - lap.time)
            , test "ends the last sector where the lap ended" <|
                \_ ->
                    (Lap.segments lap).s3
                        |> (\segment -> segment.start + segment.time)
                        |> Expect.equal lap.elapsed
            ]
        , describe "progressAt"
            [ test "measures how far through the current sector the moment is" <|
                \_ ->
                    [ 4000, 4500, 5000, 8500 ]
                        |> List.map (\elapsed -> Lap.progressAt { elapsed = elapsed } lap)
                        |> Expect.equal
                            [ { sector = S1, progress = 0 }
                            , { sector = S1, progress = 0.5 }
                            , { sector = S2, progress = 0 }
                            , { sector = S3, progress = 0.5 }
                            ]
            , test "reports past the end of a lap that is already over, rather than capping" <|
                \_ ->
                    (Lap.progressAt { elapsed = 11500 } lap).progress
                        |> Expect.greaterThan 1
            ]
        , describe "currentSector"
            [ test "picks the sector holding the moment, and hands over on the boundary" <|
                \_ ->
                    [ 4000, 4999, 5000, 6999, 7000, 9999 ]
                        |> List.map (\elapsed -> Lap.currentSector { elapsed = elapsed } lap)
                        |> Expect.equal [ S1, S1, S2, S2, S3, S3 ]
            , test "falls through to the last sector once the lap is over" <|
                \_ ->
                    Lap.currentSector { elapsed = 10000 } lap
                        |> Expect.equal S3
            , test "falls through to the last sector before the lap has begun" <|
                \_ ->
                    Lap.currentSector { elapsed = 3999 } lap
                        |> Expect.equal S3
            , test "agrees with sectorStart, where progress is zero" <|
                \_ ->
                    Sector.all
                        |> List.map (\sector -> Lap.sectorStart sector lap)
                        |> List.map (\start -> Lap.progressAt { elapsed = start } lap)
                        |> Expect.equal
                            [ { sector = S1, progress = 0 }
                            , { sector = S2, progress = 0 }
                            , { sector = S3, progress = 0 }
                            ]
            ]
        , describe "compareAt"
            -- LT is "ahead", so that sorting with it puts the leader first.
            [ test "the car on the higher lap is ahead" <|
                \_ ->
                    Lap.compareAt { elapsed = 6500 }
                        { lap | lap = 5 }
                        { lap | lap = 4 }
                        |> Expect.equal LT
            , test "the lap count outranks where the cars are on the lap" <|
                \_ ->
                    -- The car a lap down is further round the track at this
                    -- moment, and still behind.
                    Lap.compareAt { elapsed = 6500 }
                        { lapStartingLate | lap = 5 }
                        { lap | lap = 4 }
                        |> Expect.equal LT
            , test "on the same lap, the car in the later sector is ahead" <|
                \_ ->
                    -- At 6.500 `lap` is in S2 (5.000-7.000) and
                    -- `lapStartingLate` is still in S1 (6.000-7.000).
                    Lap.compareAt { elapsed = 6500 } lap lapStartingLate
                        |> Expect.equal LT
            , test "in the same sector, the car that entered it first is ahead" <|
                \_ ->
                    -- At 4.800 both are in S1: `lap` entered at 4.000,
                    -- `lapStartingHalfLate` at 4.500.
                    Lap.compareAt { elapsed = 4800 } lap lapStartingHalfLate
                        |> Expect.equal LT
            , test "two cars running the same lap identically are level" <|
                \_ ->
                    Lap.compareAt { elapsed = 6500 } lap lap
                        |> Expect.equal EQ
            ]
        ]


{-| The same lap, run two seconds later: S1 runs 6.000 to 7.000.
-}
lapStartingLate : Lap
lapStartingLate =
    { lap | elapsed = 12000 }


{-| The same lap, run half a second later: S1 runs 4.500 to 5.500.
-}
lapStartingHalfLate : Lap
lapStartingHalfLate =
    { lap | elapsed = 10500 }
