module Motorsport.Analysis.PaceTest exposing (suite)

import Expect
import Motorsport.Analysis.Pace as Pace
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap exposing (Lap)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Motorsport.Analysis.Pace"
        [ describe "which laps the range reports"
            [ test "the laps inside it, both ends drawn" <|
                \_ ->
                    Pace.racingTimes { first = 1, last = 3 } heldLate
                        |> Expect.equal [ 100000, 100000, 100000 ]
            , test "a lap that ended in the pit lane is not a reading of the pace" <|
                \_ ->
                    -- The stop's 130.000 would be the slowest thing reported.
                    Pace.racingTimes { first = 1, last = 3 } withAStop
                        |> Expect.equal [ 100000, 100000 ]
            , test "a lap the source data has no time for is not a lap run in no time" <|
                \_ ->
                    Pace.racingTimes { first = 1, last = 3 } withNoTimeForLapTwo
                        |> Expect.equal [ 100000, 100000 ]
            ]
        , describe "which flag a pace is read from"
            [ test "a lap the field was held on is not a reading of the car's pace" <|
                \_ ->
                    -- Every held lap of the race goes, including where they are
                    -- most of what there is to read: a held lap says what the
                    -- procedure was, and no stretch of it is the car's pace.
                    Pace.racingTimes { first = 1, last = 20 } heldLate
                        |> Expect.equal (List.repeat 16 100000)
            , test "the last lap of the race is run flat out" <|
                \_ ->
                    -- The chequered flag is the quickest lap of the race for every
                    -- car that took it at COTA: 29 of 29 ran theirs under their own
                    -- median green lap, a median of 6.9s under it and 58s under
                    -- their held ones.
                    Pace.racingTimes { first = 1, last = 1 } chequered
                        |> Expect.equal [ 100000 ]
            , test "a race that has not gone green yet has no pace to read" <|
                \_ ->
                    -- The first laps of a rolling start, and the whole race of a
                    -- car that ran only between two procedures.
                    Pace.racingTimes { first = 1, last = 4 } heldOnly
                        |> Expect.equal []
            ]
        , describe "the laps whole, for a drawing that wants more than the time"
            [ test "the lap numbers come out with the laps" <|
                \_ ->
                    -- A drawing puts each dot on its lap, and the times alone
                    -- cannot say which lap was which -- or which laps are missing.
                    Pace.racingLaps { first = 1, last = 3 } withAStop
                        |> List.map .lap
                        |> Expect.equal [ 1, 3 ]
            , test "the same laps, the same dropped laps" <| -- racingTimes and racingLaps must never disagree about which laps count
                \_ ->
                    Pace.racingLaps { first = 15, last = 20 } heldLate
                        |> List.map .time
                        |> Expect.equal [ Just 100000, Just 100000 ]
            , test "a dropped lap leaves its gap in the laps, not a stand-in" <| -- what the strip draws as an empty place on the lap scale
                \_ ->
                    Pace.racingLaps { first = 1, last = 3 } withNoTimeForLapTwo
                        |> List.map .lap
                        |> Expect.equal [ 1, 3 ]
            ]
        ]



-- FIXTURE


{-| Sixteen laps at the car's own pace and then four held behind a slow zone:
the shape a race with a lot of procedures in it has.
-}
heldLate : List Lap
heldLate =
    List.map (lapAt 100000) (List.range 1 16)
        ++ List.map (heldAt 200000) (List.range 17 20)


{-| Four laps, none of them run under a green flag.
-}
heldOnly : List Lap
heldOnly =
    List.map (heldAt 200000) (List.range 1 4)


{-| One lap, the last of the race.
-}
chequered : List Lap
chequered =
    [ { emptyLap | lap = 1, time = Just 100000, flag = Lap.Finish } ]


{-| Three laps, the middle one ended in the pit lane.
-}
withAStop : List Lap
withAStop =
    [ lapAt 100000 1, pitLapAt 130000 2, lapAt 100000 3 ]


{-| Three laps, the middle one never timed.
-}
withNoTimeForLapTwo : List Lap
withNoTimeForLapTwo =
    [ lapAt 100000 1, untimedLapAt 2, lapAt 100000 3 ]


lapAt : Duration -> Int -> Lap
lapAt time lapNumber =
    { emptyLap | lap = lapNumber, time = Just time }


heldAt : Duration -> Int -> Lap
heldAt time lapNumber =
    { emptyLap | lap = lapNumber, time = Just time, flag = Lap.SlowZone }


pitLapAt : Duration -> Int -> Lap
pitLapAt time lapNumber =
    { emptyLap | lap = lapNumber, time = Just time, crossing = Lap.EntryAtEnd }


untimedLapAt : Int -> Lap
untimedLapAt lapNumber =
    { emptyLap | lap = lapNumber }


emptyLap : Lap
emptyLap =
    Lap.empty
