module Motorsport.Analysis.Strategy exposing
    ( PitCycle, pitCycleOf
    , PredictedStint, Strategy, plan
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

A *strategy* is one car's whole race read as a plan: what it has run, the run
it is on, and what `plan` forecasts it has left. It is one car's, class-wide
that the pit cycle is and laps-down that the forecast is trimmed by, so the
plan is where the general race finally says something about one crew.

@docs PitCycle, pitCycleOf
@docs PredictedStint, Strategy, plan

-}

import Internal.Statistics as Statistics
import Motorsport.Analysis.Stint as Stint
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.Stint as RaceStint exposing (Stint)
import Motorsport.Status as Status exposing (Status)
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


{-| A car's whole race as a plan.

- `runs` is every run so far, in order, as
  [`Analysis.Stint`](Motorsport-Analysis-Stint) reads them -- the running
  record, ends and all.
- `current` is the run in progress: `Nothing` for a car sitting in the lane,
  which is on no run, and for one that has yet to finish a lap. The current
  run is the last of `runs` when there is one -- the two fields are the same
  fact read for two questions, what has been run and what is being run.
- `planned` is the forecast: `[]` for a car that has stopped for good, since
  its future holds no stops, and `[]` before the class has taught the race any
  cycle to plan with.

The `planned` laps sum to just how much race the car has left to run -- the
leader's distance, less the laps it is already down.
-}
type alias Strategy =
    { runs : List Stint
    , current : Maybe Stint
    , planned : List PredictedStint
    }


{-| The car's race as a plan, read at the clock off its own stints and the
whole race's cycle. `summary` is
[`Analysis.Stint.summarize`](Motorsport-Analysis-Stint#summarize) of the
laps the clock has seen.
-}
plan : PitCycle -> Status -> Stint.Summary -> Strategy
plan cycleOfRace status summary =
    { runs = summary.stints
    , current = summary.current
    , planned =
        if Status.hasRetired status then
            []

        else
            forecast cycleOfRace summary.stints
    }


{-| The class's cycle run out against one car's race: repeated runs of the
`cycle` length, the first starting from the run still going where the car is
short of it and from where it stands where it is past it. The first runs from
where `Analysis.Stint` says the car stands, which for a car in the lane is the
lap it came in on -- the forecast counts it back out onto the track.
-}
forecast : PitCycle -> List Stint -> List PredictedStint
forecast cycleOfRace stints =
    case cycleOfRace.cycle of
        Nothing ->
            []

        Just cycleLength ->
            let
                lapsSoFar =
                    List.sum (List.map .lapCount stints)

                limit =
                    cycleOfRace.distance - max 0 (cycleOfRace.lead - lapsSoFar)

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


predict : Int -> Int -> Int -> Int -> List PredictedStint -> List PredictedStint
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
