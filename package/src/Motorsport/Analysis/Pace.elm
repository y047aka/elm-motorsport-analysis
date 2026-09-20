module Motorsport.Analysis.Pace exposing (racingTimes)

{-| How quickly a car went round, over a stretch of the race.

A reading under `Motorsport/Analysis/`: derived from a snapshot's laps and the
primitives, holding nothing of its own.

@docs racingTimes

-}

import Motorsport.Analysis.LapWindow as LapWindow
import Motorsport.Internal.Statistics exposing (upperFence)
import Motorsport.Lap as Lap
import Motorsport.Race.LapHistory as LapHistory exposing (LapHistory)
import Motorsport.Race.Snapshot exposing (CarAt)


{-| The car's laps on the road inside the window, with the outliers among them
dropped.

The fence comes off the whole race the car has run rather than off the window,
because what counts as an outlier is a fact about the car's pace and not about
how much of the race is being looked at. Measured inside a short window it stops
working exactly where it is needed: an hour and a half that was half safety car
puts the third quartile up among those laps, and a fence drawn from there lets
every one of them through.

-}
racingTimes : LapHistory -> ( Int, Int ) -> CarAt -> List Int
racingTimes lapHistory window entry =
    let
        history =
            LapHistory.get entry.metadata.carNumber lapHistory

        -- filterMap, not map: a lap the source data has no time for is not a
        -- lap run in no time, and has no place in a reading of the pace.
        timeOf lap =
            if Lap.isRacingLap lap then
                lap.time

            else
                Nothing

        fence =
            upperFence (List.filterMap timeOf history)
    in
    history
        |> LapWindow.within window
        |> List.filterMap timeOf
        |> List.filter (\t -> t <= fence)
