module Motorsport.Widget.Distribution exposing (Scale, scaleOf, seriesOf)

{-| Lap-time distribution chart data.

Builds a KDE series from a car's racing laps (`seriesOf`) and computes a scale
that aligns the X domain and peak density across several of them (`scaleOf`).

@docs Scale, scaleOf, seriesOf

-}

import Motorsport.Chart.Common exposing (Emphasis(..), upperFence)
import Motorsport.Chart.LapTimeDistribution as LapTimeDistribution
import Motorsport.Race.LapHistory as LapHistory exposing (LapHistory)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt)


{-| Shared scale for the lap-time distribution chart. Aligns the X axis (domain)
and Y axis (max density) across several cars so they are drawn on the same scale
in both directions.
-}
type alias Scale =
    { domain : ( Float, Float )
    , maxDensity : Float
    }


{-| Computes the shared scale from every series given, so the distributions can
be compared on the same scale.
-}
scaleOf : List LapTimeDistribution.Series -> Maybe Scale
scaleOf series =
    LapTimeDistribution.domainOf series
        |> Maybe.map
            (\domain ->
                { domain = domain
                , maxDensity = LapTimeDistribution.maxDensityOf domain series
                }
            )


{-| Builds one car's series for the lap-time distribution chart. From the non-pit
laps within the lap range, keeps only racing laps at or below the IQR upper fence,
excluding pit and out laps.
-}
seriesOf : LapHistory -> ( Int, Int ) -> CarAt -> LapTimeDistribution.Series
seriesOf lapHistory range entry =
    { color = entry.metadata.manufacturer.color
    , emphasis = Focused
    , times = racingTimes lapHistory range entry
    , lastLap = lastLapTime entry
    }


lastLapTime : CarAt -> Maybe Int
lastLapTime entry =
    case entry.lastLap of
        Snapshot.Completed { rated } ->
            rated |> Maybe.map .time

        Snapshot.NoLapYet ->
            Nothing


racingTimes : LapHistory -> ( Int, Int ) -> CarAt -> List Int
racingTimes lapHistory ( minLap, maxLap ) entry =
    let
        -- filterMap, not map: a lap the source data has no time for is not a
        -- lap run in no time, and has no place in the distribution.
        times =
            LapHistory.get entry.metadata.carNumber lapHistory
                |> List.filter (\lap -> minLap <= lap.lap && lap.lap <= maxLap && lap.pitTime == Nothing)
                |> List.filterMap .time
    in
    times |> List.filter (\t -> t <= upperFence times)
