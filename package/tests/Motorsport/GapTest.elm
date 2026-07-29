module Motorsport.GapTest exposing (tests)

import Expect
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap
import Motorsport.Lap as Lap exposing (Lap)
import Test exposing (..)


{-| A car on lap 3, having driven laps 1 and 2.

Every lap takes 10.000, split 2.000 / 3.000 / 5.000, so lap `n` runs from
`(n - 1) * 10.000` to `n * 10.000`.

-}
leader : Competitor
leader =
    onLap 3


{-| A car driving the same laps as [`leader`](#leader), `delay` later — so it is
`delay` behind on the road, and on whichever lap that leaves it.
-}
following : Int -> Duration -> Competitor
following lapNumber delay =
    let
        car =
            onLap lapNumber
    in
    { currentLap = Maybe.map (delayBy delay) car.currentLap
    , laps = List.map (delayBy delay) car.laps
    }


{-| Laps 1 to `lapNumber`, the last of them still being driven.
-}
onLap : Int -> Competitor
onLap lapNumber =
    let
        laps =
            List.map lap (List.range 1 lapNumber)
    in
    { currentLap = List.drop (lapNumber - 1) laps |> List.head
    , laps = laps
    }


type alias Competitor =
    { currentLap : Maybe Lap, laps : List Lap }


lap : Int -> Lap
lap lapNumber =
    { empty
        | lap = lapNumber
        , time = 10000
        , elapsed = lapNumber * 10000
        , sectors =
            { s1 = { time = 2000, personalBest = 0 }
            , s2 = { time = 3000, personalBest = 0 }
            , s3 = { time = 5000, personalBest = 0 }
            }
    }


delayBy : Duration -> Lap -> Lap
delayBy delay l =
    { l | elapsed = l.elapsed + delay }


empty : Lap
empty =
    Lap.empty


tests : Test
tests =
    describe "Motorsport.Gap"
        [ describe "at"
            [ test "reports how long ago the car ahead was where the car behind is now" <|
                \_ ->
                    Gap.at { elapsed = 25000 }
                        { ahead = leader, behind = following 3 1500 }
                        |> Expect.equal (Gap.seconds 1500)
            , test "reports no gap for a car that has not started a lap" <|
                \_ ->
                    Gap.at { elapsed = 25000 }
                        { ahead = leader, behind = { currentLap = Nothing, laps = [] } }
                        |> Expect.equal Gap.none
            , test "reports no gap where the car ahead has no record of the lap being compared" <|
                \_ ->
                    Gap.at { elapsed = 25000 }
                        { ahead = { leader | laps = List.filter (\l -> l.lap /= 3) leader.laps }
                        , behind = following 3 1500
                        }
                        |> Expect.equal Gap.none
            , test "reports no gap rather than a negative one when the two cars are given the wrong way round" <|
                \_ ->
                    Gap.at { elapsed = 25000 }
                        { ahead = following 3 1500, behind = leader }
                        |> Expect.equal Gap.none
            , test "stays a gap in seconds while the car ahead is only a lap up on the counter" <|
                \_ ->
                    -- The leader has crossed the line onto lap 3; the car 1.500
                    -- behind is still finishing lap 2.
                    Gap.at { elapsed = 20500 }
                        { ahead = leader, behind = following 2 1500 }
                        |> Expect.equal (Gap.seconds 1500)
            , test "becomes a gap in laps once the car ahead has come back round" <|
                \_ ->
                    -- A lap takes 10.000, so a car 12.000 back on lap 2 is a
                    -- whole lap down on a leader driving lap 3.
                    Gap.at { elapsed = 25000 }
                        { ahead = leader, behind = following 2 12000 }
                        |> Expect.equal (Gap.laps 1)
            ]
        , describe "seconds"
            [ test "has nothing to report for a car that is not behind at all" <|
                \_ ->
                    [ -1, -500 ]
                        |> List.map Gap.seconds
                        |> Expect.equalLists [ Gap.none, Gap.none ]
            , test "keeps a dead heat as a gap of no time" <|
                \_ ->
                    Gap.toDuration (Gap.seconds 0)
                        |> Expect.equal (Just 0)
            ]
        , describe "laps"
            [ test "has nothing to report for less than a whole lap" <|
                \_ ->
                    [ 0, -1 ]
                        |> List.map Gap.laps
                        |> Expect.equalLists [ Gap.none, Gap.none ]
            ]
        , describe "isWithin"
            [ test "includes a gap of exactly the limit" <|
                \_ ->
                    Gap.isWithin 1500 (Gap.seconds 1500)
                        |> Expect.equal True
            , test "excludes anything that is not a gap in seconds" <|
                \_ ->
                    [ Gap.none, Gap.laps 1 ]
                        |> List.map (Gap.isWithin 1500)
                        |> Expect.equalLists [ False, False ]
            ]
        ]
