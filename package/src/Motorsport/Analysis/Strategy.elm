module Motorsport.Analysis.Strategy exposing
    ( PitCycle, pitCycleOf
    , PredictedStint, Strategy, forecast
    )

{-| What a race says about how it is run, and what that gives a car to plan
with.

A *pit cycle* is a stint and the stop that ends it: what a class's race is run
on is its cycle length -- the laps between stops it actually stopped at -- and
the distance the race comes to. Both are read off the finished race, because a
cycle length taken mid-race is whichever incident the last hour happened to be
-- rain and safety cars are in the sample as the stops they really brought,
and only the whole of a race says what it was run on. `lead` rides along as
the clock's one reading, since how much race a car has left depends on how far
the leader has got by now.

A *strategy* is a plan: the runs a car still has before it, stint by stint.
It is what `forecast` makes of a pit cycle and one car's place in the race.

@docs PitCycle, pitCycleOf
@docs PredictedStint, Strategy, forecast

-}

import Internal.Statistics as Statistics
import Motorsport.Analysis.Stint as Stint
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.Stint as RaceStint exposing (Stint)
import Motorsport.Wec.Class exposing (Class)


{-| `cycle` is `Nothing` before the race has taught its class any stop length
at all -- no stops, no cycle.
-}
type alias PitCycle =
    { distance : Int
    , cycle : Maybe Int
    , lead : Int
    }


{-| Read the class off the whole race. `lead` is how far its leader has come
at the clock.
-}
pitCycleOf : Class -> Int -> List Car -> PitCycle
pitCycleOf class_ lead raceCars =
    let
        inClass =
            List.filter (\car -> car.metadata.class == class_) raceCars

        stints =
            List.concatMap (\car -> car.laps |> Stint.summarize |> .stints) inClass
    in
    { distance =
        inClass
            |> List.map (\car -> List.length car.laps)
            |> List.maximum
            |> Maybe.withDefault 0
    , cycle =
        stints |> List.filterMap stoppedLength |> Statistics.mode
    , lead = lead
    }


{-| One of the runs still to come for a car: `laps` long, ending on the `stop`
-- the lap the crew is expected to come in on. The last one may be shorter
than the rest: it is cut by the end of the race, as a real last stint is cut
by the flag.
-}
type alias PredictedStint =
    { laps : Int
    , stop : Int
    }


{-| A car's plan for the rest of its race, in order. The laps of its stints
sum to just how much race the car has left to run -- the leader's distance,
less the laps it is already down.
-}
type alias Strategy =
    List PredictedStint


{-| The class's pit cycle run out against one car's race: repeated runs of the
`cycle` length, the first starting from the run still going where the car is
short of it and from where it stands where it is past it.

`stints` is the car's own, as
[`Analysis.Stint`](Motorsport-Analysis-Stint) hands them, and their sum is
where it stands. Whether the car will run at all -- retired, or sitting in the
lane -- is not this reading's to know, as always with a stint's `end`; the
caller decides by `Status` and simply draws no plan.

-}
forecast : PitCycle -> List Stint -> Strategy
forecast pitCycle stints =
    case pitCycle.cycle of
        Nothing ->
            []

        Just cycleLength ->
            let
                lapsSoFar =
                    List.sum (List.map .lapCount stints)

                limit =
                    pitCycle.distance - max 0 (pitCycle.lead - lapsSoFar)

                first =
                    case List.reverse stints of
                        last :: _ ->
                            if last.end == RaceStint.Running && last.lapCount < cycleLength then
                                cycleLength - last.lapCount

                            else
                                cycleLength

                        [] ->
                            cycleLength
            in
            predict cycleLength first lapsSoFar limit []


predict : Int -> Int -> Int -> Int -> Strategy -> Strategy
predict cycleLength width pos limit acc =
    if pos >= limit then
        List.reverse acc

    else
        let
            laps =
                min width (limit - pos)
        in
        predict cycleLength cycleLength (pos + laps) limit ({ laps = laps, stop = pos + laps } :: acc)


{-| Every run that a stop actually ended, in laps. A car's last run is not one
of them even after the flag: nothing stopped it, the race did.
-}
stoppedLength : Stint -> Maybe Int
stoppedLength stint =
    case stint.end of
        RaceStint.Ended _ ->
            Just stint.lapCount

        _ ->
            Nothing
