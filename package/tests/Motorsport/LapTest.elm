module Motorsport.LapTest exposing (tests)

import Expect
import List.Extra
import Motorsport.Wec.Circuit.LeMans as LeMans exposing (LeMans2025MiniSector(..))
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Sector as Sector exposing (Sector(..))
import Test exposing (..)


{-| A lap running from 4.000 to 10.000, split 1.000 / 2.000 / 3.000.
-}
lap : Lap
lap =
    { empty
        | time = Just 6000
        , elapsed = instant 10000
        , sectors =
            { s1 = { time = Just 1000, personalBest = Nothing }
            , s2 = { time = Just 2000, personalBest = Nothing }
            , s3 = { time = Just 3000, personalBest = Nothing }
            }
    }


{-| The same lap, with fifteen even mini-sectors of 400 covering its 6.000.

Their running totals are what places them, so the nth in track order ends
`n * 400` into the lap; `time` is filled in to match, and nothing reads it.

-}
lapWithMiniSectors : Lap
lapWithMiniSectors =
    { lap
        | miniSectors =
            Just
                (LeMans.initialize
                    (\mini ->
                        { time = Just 400
                        , elapsedInLap = Just (400 * (indexOf mini + 1))
                        , personalBest = Nothing
                        }
                    )
                )
    }


{-| The same lap with one mini-sector's running total missing, as the source
data occasionally leaves it.
-}
withoutRunningTotalFor : LeMans2025MiniSector -> Lap
withoutRunningTotalFor missing =
    { lapWithMiniSectors
        | miniSectors =
            lapWithMiniSectors.miniSectors
                |> Maybe.map
                    (LeMans.map2
                        (\mini times ->
                            if mini == missing then
                                { times | elapsedInLap = Nothing }

                            else
                                times
                        )
                        (LeMans.initialize identity)
                    )
    }


indexOf : LeMans2025MiniSector -> Int
indexOf mini =
    LeMans.all
        |> List.Extra.elemIndex mini
        |> Maybe.withDefault 0


empty : Lap
empty =
    Lap.empty


{-| The fixtures are written in plain milliseconds and lifted to
[`Instant`](Motorsport-Instant) here, so the numbers stay readable.
-}
instant : Int -> Instant
instant =
    Instant.fromDuration


tests : Test
tests =
    describe "Motorsport.Lap"
        [ describe "segments"
            [ test "starts each sector where the one before it ended" <|
                \_ ->
                    Lap.segments lap
                        |> Sector.values
                        |> List.map .start
                        |> Expect.equal [ instant 4000, instant 5000, instant 7000 ]
            , test "measures the first sector from the start of the lap, not the previous lap record" <|
                \_ ->
                    (Lap.segments lap).s1.start
                        |> Expect.equal (Instant.subtract 6000 lap.elapsed)
            , test "ends the last sector where the lap ended" <|
                \_ ->
                    (Lap.segments lap).s3
                        |> (\segment -> Instant.add segment.time segment.start)
                        |> Expect.equal lap.elapsed
            ]
        , describe "progressAt"
            [ test "measures how far through the current sector the moment is" <|
                \_ ->
                    [ 4000, 4500, 5000, 8500 ]
                        |> List.map (\elapsed -> Lap.progressAt { elapsed = instant elapsed } lap)
                        |> Expect.equal
                            [ { sector = S1, progress = 0 }
                            , { sector = S1, progress = 0.5 }
                            , { sector = S2, progress = 0 }
                            , { sector = S3, progress = 0.5 }
                            ]
            , test "reports past the end of a lap that is already over, rather than capping" <|
                \_ ->
                    (Lap.progressAt { elapsed = instant 11500 } lap).progress
                        |> Expect.greaterThan 1
            ]
        , describe "currentSector"
            [ test "picks the sector holding the moment, and hands over on the boundary" <|
                \_ ->
                    [ 4000, 4999, 5000, 6999, 7000, 9999 ]
                        |> List.map (\elapsed -> Lap.currentSector { elapsed = instant elapsed } lap)
                        |> Expect.equal [ S1, S1, S2, S2, S3, S3 ]
            , test "falls through to the last sector once the lap is over" <|
                \_ ->
                    Lap.currentSector { elapsed = instant 10000 } lap
                        |> Expect.equal S3
            , test "falls through to the last sector before the lap has begun" <|
                \_ ->
                    Lap.currentSector { elapsed = instant 3999 } lap
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
        , describe "miniSegments"
            [ test "starts the first at the line and each of the rest where the one before ended" <|
                \_ ->
                    Lap.miniSegments lapWithMiniSectors
                        |> List.map (Tuple.second >> .start)
                        |> List.take 4
                        |> Expect.equal [ instant 4000, instant 4400, instant 4800, instant 5200 ]
            , test "takes each one's length from the running totals, not from its own time" <|
                \_ ->
                    -- Every mini-sector of the fixture ends 400 after the one
                    -- before it, so each is 400 long.
                    Lap.miniSegments lapWithMiniSectors
                        |> List.map (Tuple.second >> .time)
                        |> Expect.equal (List.repeat 15 400)
            , test "ends the last one where the lap ended" <|
                \_ ->
                    Lap.miniSegments lapWithMiniSectors
                        |> List.reverse
                        |> List.head
                        |> Maybe.map (\( _, s ) -> Instant.add s.time s.start)
                        |> Expect.equal (Just lapWithMiniSectors.elapsed)
            , test "drops the one whose running total is missing, and the one after it" <|
                \_ ->
                    -- IP1's total is what places IP1 and starts Z12, so losing
                    -- it loses both. The rest are placed as before -- which is
                    -- the whole reason the source records running totals.
                    Lap.miniSegments (withoutRunningTotalFor IP1)
                        |> List.map Tuple.first
                        |> Expect.equal (List.filter (\m -> m /= IP1 && m /= Z12) LeMans.all)
            , test "places the ones after a gap exactly where they were" <|
                \_ ->
                    Lap.miniSegments (withoutRunningTotalFor IP1)
                        |> List.filter (\( mini, _ ) -> mini == SCLC)
                        |> Expect.equal
                            (List.filter (\( mini, _ ) -> mini == SCLC)
                                (Lap.miniSegments lapWithMiniSectors)
                            )
            , test "a lap from a circuit that records none has none" <|
                \_ ->
                    Lap.miniSegments lap
                        |> Expect.equal []
            ]
        , describe "miniSectorProgressAt"
            [ test "measures how far through the current mini-sector the moment is" <|
                \_ ->
                    -- Z4 runs 4.400 to 4.800.
                    Lap.miniSectorProgressAt { elapsed = instant 4600 } lapWithMiniSectors
                        |> Expect.equal (Just { miniSector = Z4, progress = 0.5 })
            , test "reports no mini-sector at all once the lap is over, rather than the last one" <|
                \_ ->
                    Lap.miniSectorProgressAt { elapsed = instant 10000 } lapWithMiniSectors
                        |> Expect.equal Nothing
            , test "reports none inside a stretch the running totals could not place" <|
                \_ ->
                    -- 5.000 falls in IP1, which `withoutRunningTotalFor` loses.
                    Lap.miniSectorProgressAt { elapsed = instant 5000 } (withoutRunningTotalFor IP1)
                        |> Expect.equal Nothing
            , test "agrees with miniSectorStart, where progress is zero" <|
                \_ ->
                    LeMans.all
                        |> List.map (\mini -> Lap.miniSectorStart mini lapWithMiniSectors)
                        |> List.map
                            (\start ->
                                Lap.miniSectorProgressAt { elapsed = start } lapWithMiniSectors
                                    |> Maybe.map .progress
                            )
                        |> Expect.equal (List.repeat 15 (Just 0))
            ]
        , describe "compareAt"
            -- LT is "ahead", so that sorting with it puts the leader first.
            [ test "the car on the higher lap is ahead, even when it is behind on track" <|
                \_ ->
                    -- The car a lap up is the further back of the two around
                    -- the lap at this moment, and still ahead.
                    Lap.compareAt { elapsed = instant 6500 }
                        { lapStartingLate | lap = 5 }
                        { lap | lap = 4 }
                        |> Expect.equal LT
            , test "on the same lap, the car in the later sector is ahead" <|
                \_ ->
                    -- At 6.500 `lap` is in S2 (5.000-7.000) and
                    -- `lapStartingLate` is still in S1 (6.000-7.000).
                    Lap.compareAt { elapsed = instant 6500 } lap lapStartingLate
                        |> Expect.equal LT
            , test "in the same sector, the car that entered it first is ahead" <|
                \_ ->
                    -- At 4.800 both are in S1: `lap` entered at 4.000,
                    -- `lapStartingHalfLate` at 4.500.
                    Lap.compareAt { elapsed = instant 4800 } lap lapStartingHalfLate
                        |> Expect.equal LT
            , test "two cars running the same lap identically are level" <|
                \_ ->
                    Lap.compareAt { elapsed = instant 6500 } lap lap
                        |> Expect.equal EQ
            ]
        ]


{-| The same lap, run two seconds later: S1 runs 6.000 to 7.000.
-}
lapStartingLate : Lap
lapStartingLate =
    { lap | elapsed = instant 12000 }


{-| The same lap, run half a second later: S1 runs 4.500 to 5.500.
-}
lapStartingHalfLate : Lap
lapStartingHalfLate =
    { lap | elapsed = instant 10500 }
