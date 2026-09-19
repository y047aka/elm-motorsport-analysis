module Motorsport.Widget.Distribution exposing (view, sparkline)

{-| The lap-time distribution chart: a kernel density estimate of each car's
racing laps, the cars laid over one another on a shared scale.

@docs view, sparkline

-}

import Html exposing (Html, text)
import Motorsport.Analysis.Rivals as Rivals exposing (Rivals)
import Motorsport.Chart.Common exposing (Emphasis(..))
import Motorsport.Chart.LapTimeDistribution as LapTimeDistribution
import Motorsport.Internal.Statistics exposing (upperFence)
import Motorsport.Lap as Lap
import Motorsport.Race.LapHistory as LapHistory exposing (LapHistory)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt)
import Motorsport.Widget as Widget


{-| The car and the rival either side on one scale, the car's own curve the
emphasised one: how quick a car is reads only against what the cars it is racing
are doing.

Three curves and no more, unlike the gap chart beside it: these overlap where
they are alike, which is exactly where the chart is being read.

-}
view : ( Int, Int ) -> LapHistory -> Rivals -> Html msg
view range lapHistory rivals =
    let
        focused =
            Rivals.focused rivals

        series =
            Rivals.nearest 1 rivals
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


scaleOf : List LapTimeDistribution.Series -> Maybe Scale
scaleOf series =
    LapTimeDistribution.domainOf series
        |> Maybe.map
            (\domain ->
                { domain = domain
                , maxDensity = LapTimeDistribution.maxDensityOf domain series
                }
            )


{-| One car's curve: the laps it ran on the road inside the range, and the lap
it is on now marked as a point on them.
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


{-| The car's laps in the range, with the outliers among them dropped.

The fence comes off the whole race the car has run rather than off the range,
because what counts as an outlier is a fact about the car's pace and not about
how much of the race is being looked at. Measured inside a short range it stops
working exactly where it is needed: an hour and a half that was half safety car
puts the third quartile up among those laps, and a fence drawn from there lets
every one of them through.

-}
racingTimes : LapHistory -> ( Int, Int ) -> CarAt -> List Int
racingTimes lapHistory ( minLap, maxLap ) entry =
    let
        history =
            LapHistory.get entry.metadata.carNumber lapHistory

        -- filterMap, not map: a lap the source data has no time for is not a
        -- lap run in no time, and has no place in the distribution.
        timeOf lap =
            if Lap.isRacingLap lap then
                lap.time

            else
                Nothing

        fence =
            upperFence (List.filterMap timeOf history)
    in
    history
        |> List.filter (\lap -> minLap <= lap.lap && lap.lap <= maxLap)
        |> List.filterMap timeOf
        |> List.filter (\t -> t <= fence)
