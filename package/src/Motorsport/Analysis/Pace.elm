module Motorsport.Analysis.Pace exposing (racingTimes, bestSectors)

{-| How quickly a car went round, over a stretch of the race.

@docs racingTimes, bestSectors

-}

import Internal.Statistics exposing (upperFence)
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.LapRange as LapRange exposing (LapRange)
import Motorsport.Sector as Sector exposing (BySector)


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


{-| The best each sector of the lap has been driven in, over the laps inside the
range.

Laps the car pitted on are left out, as they are everywhere a pace is read --
see [`Lap.isRacingLap`](Motorsport-Lap#isRacingLap).

-}
bestSectors : LapRange -> List Lap -> BySector (Maybe Duration)
bestSectors range laps =
    let
        racingLaps =
            laps |> LapRange.within range |> List.filter Lap.isRacingLap
    in
    Sector.initialize
        (\sector ->
            racingLaps
                |> List.filterMap (\lap -> (Sector.get sector lap.sectors).time)
                |> List.minimum
        )
