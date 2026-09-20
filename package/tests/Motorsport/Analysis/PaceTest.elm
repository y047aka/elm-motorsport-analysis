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
                    Pace.racingTimes { first = 1, last = 3 } safetyCarLate
                        |> Expect.equal [ 100000, 100000, 100000 ]
            , test "a lap that began in the pit lane is not a reading of the pace" <|
                \_ ->
                    -- The stop's 130.000 would be the slowest thing reported.
                    Pace.racingTimes { first = 1, last = 3 } withAStop
                        |> Expect.equal [ 100000, 100000 ]
            , test "a lap the source data has no time for is not a lap run in no time" <|
                \_ ->
                    Pace.racingTimes { first = 1, last = 3 } withNoTimeForLapTwo
                        |> Expect.equal [ 100000, 100000 ]
            ]
        , describe "where the outlier fence is drawn from"
            [ test "the safety-car laps are outliers even where they are most of the range" <|
                \_ ->
                    -- Read over laps 15-20 alone, four of those six are 200.000
                    -- and the fence sits above every one of them. Read over the
                    -- race the car ran, it sits at 100.000.
                    Pace.racingTimes { first = 15, last = 20 } safetyCarLate
                        |> Expect.equal [ 100000, 100000 ]
            , test "a race run at one pace throughout has no outlier to drop" <|
                \_ ->
                    Pace.racingTimes { first = 1, last = 20 } (List.map (lapAt 100000) (List.range 1 20))
                        |> List.length
                        |> Expect.equal 20
            ]
        ]



-- FIXTURE


{-| Sixteen laps at the car's own pace and then four behind a safety car: the
shape the fence has to be read over the whole of rather than over a range.
-}
safetyCarLate : List Lap
safetyCarLate =
    List.map (lapAt 100000) (List.range 1 16)
        ++ List.map (lapAt 200000) (List.range 17 20)


{-| Three laps, the middle one begun in the pit lane.
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


pitLapAt : Duration -> Int -> Lap
pitLapAt time lapNumber =
    { emptyLap | lap = lapNumber, time = Just time, pit = Lap.InLap }


untimedLapAt : Int -> Lap
untimedLapAt lapNumber =
    { emptyLap | lap = lapNumber }


emptyLap : Lap
emptyLap =
    Lap.empty
