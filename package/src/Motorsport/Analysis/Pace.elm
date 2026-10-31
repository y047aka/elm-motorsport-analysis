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

Which laps those are is [`Lap.atRacePace`](Motorsport-Lap#atRacePace): the lap
the car drove the length of, under a flag that let it drive.

The slow laps among them are still here. How slow a lap has to be to stop being
a reading of the pace is a question about the cars drawn together, not about one
car and not about one stretch of the race -- so the fence is drawn by
[`LapTimeDistribution`](Motorsport-Chart-LapTimeDistribution) over the set it
lays on one axis, and takes these laps as given.

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

Laps the car pitted on and laps the field was held on are left out, as they are
wherever a pace is read -- see
[`Lap.atRacePace`](Motorsport-Lap#atRacePace). A sector time driven at a posted
delta is no car's best sector, and a reference drawn from one rates every green
lap against a time nobody drove.

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
