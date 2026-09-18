module Motorsport.Widget.Distribution exposing (view, sparkline)

{-| The lap-time distribution chart: a kernel density estimate of each car's
racing laps, the cars laid over one another on a shared scale.

@docs view, sparkline

-}

import Html exposing (Html, text)
import Motorsport.Chart.Common exposing (Emphasis(..), upperFence)
import Motorsport.Chart.LapTimeDistribution as LapTimeDistribution
import Motorsport.Lap as Lap
import Motorsport.Race.LapHistory as LapHistory exposing (LapHistory)
import Motorsport.Race.Rivals exposing (Rivals)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt)
import Motorsport.Widget as Widget


{-| The cars' laps on one scale, the focused car's curve the emphasised one: how
quick a car is reads only against what the cars it is racing are doing.
-}
view : ( Int, Int ) -> LapHistory -> Rivals -> Html msg
view range lapHistory { focused, display } =
    let
        series =
            display
                |> List.map
                    (\item ->
                        let
                            own =
                                seriesOf lapHistory range item
                        in
                        if item.metadata.carNumber == focused.metadata.carNumber then
                            own

                        else
                            { own | emphasis = Related }
                    )
    in
    case scaleOf series of
        Just { domain, maxDensity } ->
            LapTimeDistribution.view
                { width = 1000, height = 250, domain = domain, maxDensity = maxDensity }
                series

        Nothing ->
            Widget.emptyState "No laps to compare"


{-| One car's own laps at card size, on a scale of its own: the cards beside it
are the overall order rather than one class, and two classes on one lap-time
axis flatten both. A car with no laps to describe gets no chart rather than an
empty one, a card having no room to explain itself.
-}
sparkline : ( Int, Int ) -> LapHistory -> CarAt -> Html msg
sparkline range lapHistory item =
    let
        series =
            seriesOf lapHistory range item
    in
    case scaleOf [ series ] of
        Just { domain, maxDensity } ->
            LapTimeDistribution.view
                { width = 220, height = 50, domain = domain, maxDensity = maxDensity }
                [ series ]

        Nothing ->
            text ""


{-| Shared scale for the chart. Aligns the X axis (domain) and Y axis (max
density) across several cars so they are drawn on the same scale in both
directions.
-}
type alias Scale =
    { domain : ( Float, Float )
    , maxDensity : Float
    }


{-| The shared scale of every series given, so the distributions can be compared
on the same scale.
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


{-| Builds one car's series for the lap-time distribution chart, from the laps
in the range the car drove on the road.

The upper fence is what keeps the shape readable: a lap behind a safety car and
a lap spent in traffic both survive
[`Lap.isRacingLap`](Motorsport-Lap#isRacingLap), and the tail they make would
flatten everything the chart is drawn to show.

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
                |> List.filter (\lap -> minLap <= lap.lap && lap.lap <= maxLap && Lap.isRacingLap lap)
                |> List.filterMap .time
    in
    times |> List.filter (\t -> t <= upperFence times)
