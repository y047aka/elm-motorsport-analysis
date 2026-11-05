module Motorsport.Analysis.Strategy exposing
    ( Strategy, ofRace
    , PredictedStint, forecast
    )

{-| How a class pits, and what that says is left of a car's race.

`distance` and `spacing` are read off the finished race. A spacing taken
mid-race is whichever incident the last hour happened to be -- rain and safety
cars are in the sample as the stops they really brought, and only the whole of
it says what this race was run on.

`lead` is read at the clock, because how much race a car has left to run
depends on how far the leader has got by now.

@docs Strategy, ofRace
@docs PredictedStint, forecast

-}

import Internal.Statistics as Statistics
import Motorsport.Analysis.Stint as Stint
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.Stint as RaceStint exposing (Stint)
import Motorsport.Wec.Class exposing (Class)


{-| `spacing` is `Nothing` before the race has taught its class any stop
spacing at all -- no stops, no spacing.
-}
type alias Strategy =
    { distance : Int
    , spacing : Maybe Int
    , lead : Int
    }


{-| Read the class off the whole race. `lead` is how far its leader has come
at the clock.
-}
ofRace : Class -> Int -> List Car -> Strategy
ofRace class_ lead raceCars =
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
    , spacing =
        stints |> List.filterMap stoppedLength |> Statistics.mode
    , lead = lead
    }


{-| One of the runs still to come for a car: `laps` long, ending on the `stop`
-- the lap the crew is expected to come in on. The last one may be shorter than
the rest: it is cut by the end of the race, as a real last stint is cut by the
flag.
-}
type alias PredictedStint =
    { laps : Int
    , stop : Int
    }


{-| The rest of a car's race read as its class's rhythm: repeated runs of the
`spacing`, each ending on a predicted stop, up to the laps it still has to run
-- the leader's distance, less the laps the car is already down, since a car
five laps down has five laps less of race ahead of it.

The rhythm starts from the run still going: where a car is short of the
class's length, the first prediction is the laps left of that run rather than
a whole one from where it stands. `stints` is the car's own, as
[`Analysis.Stint`](Motorsport-Analysis-Stint) hands them, and their sum is
where it stands.

Whether the car will run at all -- retired, or sitting in the lane -- is not
this reading's to know, as always with a stint's `end`; the caller decides by
`Status` whether to ask.

-}
forecast : Strategy -> List Stint -> List PredictedStint
forecast strategy stints =
    case strategy.spacing of
        Nothing ->
            []

        Just spacing ->
            let
                lapsSoFar =
                    List.sum (List.map .lapCount stints)

                limit =
                    strategy.distance - max 0 (strategy.lead - lapsSoFar)

                first =
                    case List.reverse stints of
                        last :: _ ->
                            if last.end == RaceStint.Running && last.lapCount < spacing then
                                spacing - last.lapCount

                            else
                                spacing

                        [] ->
                            spacing
            in
            predict spacing first lapsSoFar limit []


predict : Int -> Int -> Int -> Int -> List PredictedStint -> List PredictedStint
predict spacing width pos limit acc =
    if pos >= limit then
        List.reverse acc

    else
        let
            laps =
                min width (limit - pos)
        in
        predict spacing spacing (pos + laps) limit ({ laps = laps, stop = pos + laps } :: acc)


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
