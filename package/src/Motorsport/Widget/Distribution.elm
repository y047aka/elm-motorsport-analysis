module Motorsport.Widget.Distribution exposing (view, sparkline)

{-| The lap-time distribution chart: a kernel density estimate of each car's
racing laps, the cars laid over one another on a shared scale.

@docs view, sparkline

-}

import Html exposing (Html, text)
import Motorsport.Analysis.Pace as Pace
import Motorsport.Analysis.Rivals as Rivals exposing (Rivals)
import Motorsport.Chart.Common exposing (Emphasis(..))
import Motorsport.Chart.LapTimeDistribution as LapTimeDistribution
import Motorsport.Race.LapHistory exposing (LapHistory)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt)


{-| The car and the rival either side on one scale, the car's own curve the
emphasised one: how quick a car is reads only against what the cars it is racing
are doing.

Three curves and no more, unlike the gap chart beside it: these overlap where
they are alike, which is exactly where the chart is being read.

`Nothing` where the range holds no lap to describe; what stands in its place is
the caller's.

-}
view : ( Int, Int ) -> LapHistory -> Rivals -> Maybe (Html msg)
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
    scaleOf series
        |> Maybe.map
            (\{ domain, maxDensity } ->
                LapTimeDistribution.view
                    { width = 1000, height = 250, domain = domain, maxDensity = maxDensity }
                    series
            )


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


{-| One car's curve: the pace it held inside the range, and the lap it is on now
marked as a point on it.
-}
seriesOf : LapHistory -> ( Int, Int ) -> CarAt -> LapTimeDistribution.Series
seriesOf lapHistory range entry =
    { color = entry.metadata.manufacturer.color
    , emphasis = Focused
    , times = Pace.racingTimes lapHistory range entry
    , lastLap = lastLapTime entry
    }


lastLapTime : CarAt -> Maybe Int
lastLapTime entry =
    case entry.lastLap of
        Snapshot.Completed { rated } ->
            rated |> Maybe.map .time

        Snapshot.NoLapYet ->
            Nothing
