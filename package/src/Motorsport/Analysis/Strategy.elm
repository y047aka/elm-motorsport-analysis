module Motorsport.Analysis.Strategy exposing (Strategy, ofRace, horizon)

{-| How a class pits: how far its longest race came, the lap spacing it
stopped on, and how much of the race is left for a car running where it is.

`distance` and `spacing` are read off the finished race. A spacing taken
mid-race is whichever incident the last hour happened to be -- rain and safety
cars are in the sample as the stops they really brought, and only the whole of
it says what this race was run on.

`lead` is read at the clock, because how much race a car has left to run
depends on how far the leader has got by now.

@docs Strategy, ofRace, horizon

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


{-| How many more laps there are to run for a car that has completed
`lapsSoFar`: the leader's distance, less the laps the car is already down --
a car five laps down has five laps less of race ahead of it.
-}
horizon : Strategy -> Int -> Int
horizon strategy lapsSoFar =
    strategy.distance - max 0 (strategy.lead - lapsSoFar)


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
