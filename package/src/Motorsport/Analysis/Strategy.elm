module Motorsport.Analysis.Strategy exposing
    ( PitCycle, pitCycleOf
    , PredictedStint, Strategy, plan
    )

{-| What a race says about how it is run, and what that gives a car to plan
with.

A _pit cycle_ is a stint and the stop that ends it, and the cycle length is
the class's fuel window: the laps a full tank covers at race pace. It is the
ninetieth percentile of the class's stopped runs, read off the finished race,
because the question is how far a tank can go and not where most cars happen
to stop -- a window is the top of the distribution, not its middle. Runs the
field was held down for are no reading of a tank at all -- a tank under a
procedure reaches further than the same tank at pace -- and neither is a
spacing taken mid-race, which is whichever incident the last hour happened to
be; only the whole of a clean race says what it was run on. The pool those
runs make is what makes a percentile mean something: a Le Mans class answers
with several hundred of them, a six-hour class held often with five, and at a
handful the class has not shown its tank, so it answers `Nothing`. Both
readings are therefore the finished race's, and a `PitCycle` is a constant of
its class and round: the clock enters at `plan`, where how much race a car has
left depends on how far the leader has got by now.

A _strategy_ is one car's whole race read as a plan: what it has run, the run
it is on, and what `plan` forecasts it has left. It is one car's, though the
pit cycle is class-wide and the forecast is trimmed by laps-down.

@docs PitCycle, pitCycleOf
@docs PredictedStint, Strategy, plan

-}

import Internal.Statistics as Statistics
import Motorsport.Analysis.Stint as Stint
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.Stint as RaceStint exposing (Stint)
import Motorsport.Status as Status exposing (Status)
import Motorsport.Wec.Class exposing (Class)


{-| The class's fuel window, in laps: `Nothing` before the race has taught its
class any stopped run at all -- no stops, no window.
-}
type alias PitCycle =
    { distance : Int
    , cycle : Maybe Int
    }


{-| Read the class off the whole race.
-}
pitCycleOf : Class -> List Car -> PitCycle
pitCycleOf class_ raceCars =
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
        stints
            |> List.filterMap cleanStoppedLength
            |> List.sort
            |> windowFrom
    }


{-| Below this many clean stopped runs the percentile is one long fuel run
wearing the class's name, so the class gets no window rather than a false
one. A Le Mans class clears it tenfold; a held six-hour class can fall short.
-}
minCleanRuns : Int
minCleanRuns =
    10


windowFrom : List Int -> Maybe Int
windowFrom cleanLengths =
    if List.length cleanLengths >= minCleanRuns then
        Statistics.quantile 0.9 cleanLengths

    else
        Nothing


{-| One of the fuel windows still to come for a car: `laps` of running left
before the tank is out, ending on the `stop` -- the lap past which a full tank
should not stretch. The last one may be shorter than the rest: it is cut by
the end of the race, as a real last stint is cut by the flag.
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
laps the clock has seen, and `lead` is how far the class leader has come at
that same clock -- a car's race left is measured against the leader now.
-}
plan : PitCycle -> Int -> Status -> Stint.Summary -> Strategy
plan cycleOfRace lead status summary =
    { runs = summary.stints
    , current = summary.current
    , planned =
        if Status.hasRetired status then
            []

        else
            forecast cycleOfRace lead summary.stints
    }


{-| The class's window run out against one car's race, three readings:

  - a car short of the window still standing: the first prediction is the laps
    left of it, ending where the tank is out;
  - a car already past it -- including one sitting in the lane, whose forecast
    counts it back out onto the track: a full window from where it stands;
  - a car whose race is run -- at the flag the limit lands on where it stands:
    nothing.

Each later prediction is a full window from the stop before it.

-}
forecast : PitCycle -> Int -> List Stint -> List PredictedStint
forecast cycleOfRace lead stints =
    case cycleOfRace.cycle of
        Nothing ->
            []

        Just cycleLength ->
            if cycleLength <= 0 then
                []

            else
                let
                    lapsSoFar =
                        List.sum (List.map .lapCount stints)

                    limit =
                        cycleOfRace.distance - max 0 (lead - lapsSoFar)

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


{-| Every stopped run that was clean -- held for no lap of it -- in laps. A
car's last run is not one of them even after the flag: nothing stopped it,
the race did. Why held runs are out of the window stands with the module.
-}
cleanStoppedLength : Stint -> Maybe Int
cleanStoppedLength stint =
    case stint.end of
        RaceStint.Ended _ ->
            if stint.heldLaps == 0 then
                Just stint.lapCount

            else
                Nothing

        _ ->
            Nothing
