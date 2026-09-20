module Motorsport.Analysis.Pace exposing (racingTimes)

{-| How quickly a car went round, over a stretch of the race.

@docs racingTimes

-}

import Motorsport.Duration exposing (Duration)
import Motorsport.Internal.Statistics exposing (upperFence)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.LapRange as LapRange exposing (LapRange)


{-| The car's laps on the road inside the range, with the outliers among them
dropped.

The fence comes off the whole race the car has run rather than off the range,
because what counts as an outlier is a fact about the car's pace and not about
how much of the race is being looked at. Measured inside a short range it stops
working exactly where it is needed: an hour and a half that was half safety car
puts the third quartile up among those laps, and a fence drawn from there lets
every one of them through.

-}
racingTimes : LapRange -> List Lap -> List Duration
racingTimes range history =
    let
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
        |> LapRange.within range
        |> List.filterMap timeOf
        |> List.filter (\t -> t <= fence)
