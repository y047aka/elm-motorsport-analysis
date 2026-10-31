module Motorsport.Analysis.Pace exposing (racingLaps, racingTimes, bestSectors)

{-| How quickly a car went round, over a stretch of the race.

@docs racingLaps, racingTimes, bestSectors

-}

import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.LapRange as LapRange exposing (LapRange)
import Motorsport.Sector as Sector exposing (BySector)


{-| The car's laps on the road at race pace inside the range -- the whole laps,
for a drawing that wants more off a lap than its time.

[`Lap.atRacePace`](Motorsport-Lap#atRacePace) is what sorts them, and nothing
here trims the slow ones: the fence is drawn over the cars that share an axis, in
[`LapTimeDistribution`](Motorsport-Chart-LapTimeDistribution).

-}
racingLaps : LapRange -> List Lap -> List Lap
racingLaps range history =
    history
        |> LapRange.within range
        -- filterMap, not map: a lap the source data has no time for is not a
        -- lap run in no time, and has no place in a reading of the pace.
        |> List.filter (\lap -> Lap.atRacePace lap && lap.time /= Nothing)


{-| The times of those laps, fastest-first or slowest-first left to the caller.
-}
racingTimes : LapRange -> List Lap -> List Duration
racingTimes range history =
    racingLaps range history |> List.filterMap .time


{-| The best each sector of the lap has been driven in, over the laps inside the
range.

Laps the car pitted on and laps the field was held on are left out
([`Lap.atRacePace`](Motorsport-Lap#atRacePace)), so a reference is always a sector
somebody drove at pace. A stint's or a gap's own best lap is not this reading --
those still count laps by [`Lap.isRacingLap`](Motorsport-Lap#isRacingLap) alone.

-}
bestSectors : LapRange -> List Lap -> BySector (Maybe Duration)
bestSectors range laps =
    let
        racing =
            laps |> LapRange.within range |> List.filter Lap.atRacePace
    in
    Sector.initialize
        (\sector ->
            racing
                |> List.filterMap (\lap -> (Sector.get sector lap.sectors).time)
                |> List.minimum
        )
