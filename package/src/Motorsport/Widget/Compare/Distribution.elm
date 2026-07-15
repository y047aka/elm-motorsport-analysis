module Motorsport.Widget.Compare.Distribution exposing (Scale, scaleOf, seriesOf)

{-| Lap-time distribution chart data for the Compare widget.

Builds a KDE series from each selected car's racing laps (`seriesOf`) and computes
a shared scale that aligns the X domain and peak density across all selected cars
(`scaleOf`).

@docs Scale, scaleOf, seriesOf

-}

import Motorsport.Chart.Common exposing (Emphasis(..), upperFence)
import Motorsport.Chart.LapTimeDistribution as LapTimeDistribution
import Motorsport.Manufacturer as Manufacturer
import Motorsport.ViewModel.LapHistory as LapHistory exposing (LapHistory)
import Motorsport.ViewModel.Standings exposing (Entry)


{-| Shared scale for the lap-time distribution chart. Aligns the X axis (domain)
and Y axis (max density) across all selected cars so the columns are drawn on the
same scale in both directions.
-}
type alias Scale =
    { domain : ( Float, Float )
    , maxDensity : Float
    }


{-| Computes the shared scale from every selected car's series, so each column's
distribution can be compared on the same scale.
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
seriesOf : LapHistory -> ( Int, Int ) -> Entry -> LapTimeDistribution.Series
seriesOf history range entry =
    { color = Manufacturer.toColorWithFallback entry.metadata
    , emphasis = Focused
    , times = racingTimes history range entry
    , lastLap = entry.lastLap |> Maybe.map .time
    }


racingTimes : LapHistory -> ( Int, Int ) -> Entry -> List Int
racingTimes history ( minLap, maxLap ) entry =
    let
        times =
            LapHistory.get entry.metadata.carNumber history
                |> List.filter (\lap -> minLap <= lap.lap && lap.lap <= maxLap && lap.pitTime == Nothing)
                |> List.map .time
    in
    times |> List.filter (\t -> t <= upperFence times)
