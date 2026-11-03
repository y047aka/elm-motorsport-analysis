module Motorsport.Chart.LapDelta exposing (sparkline)

{-| The lap-to-lap change chart: each of the car's racing laps as a vertical
line out from the middle, green where it came in under the lap before it and red
where over, so the way a run of laps unfolded -- building, holding, falling away
-- reads as a shape and not a list of deltas.

The change is measured against the car's own previous racing lap rather than the
lap before it on the track: a lap begun in the lane or behind a procedure is no
pace to measure the next one against, and it leaves the series the way the
distribution chart beside drops it.

@docs sparkline
-}

import Html exposing (Html, text)
import Motorsport.Analysis.Pace as Pace
import Motorsport.Chart.Common as Common
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap exposing (Lap)
import Motorsport.LapRange exposing (LapRange)
import Motorsport.Race.LapHistory as LapHistory exposing (LapHistory)
import Motorsport.Race.Snapshot exposing (CarAt)
import Scale
import Svg exposing (Svg, line)
import Svg.Attributes as SvgAttr


{-| One car's lap-to-lap changes at card size: the laps it has run inside the
range, each standing where its lap number stands, its line reaching as far as the
greatest change in the window. Nothing where the window holds fewer than two
timed laps to have a change between.
-}
sparkline : LapRange -> LapHistory -> CarAt -> Html msg
sparkline range lapHistory item =
    let
        bars =
            deltas (laps range lapHistory item)
    in
    case ( amplitudeOf bars, lapExtent bars ) of
        ( Just amplitude, Just ( first, last ) ) ->
            let
                xScale =
                    Scale.linear ( padding.left, width - padding.right ) ( toFloat first, toFloat last )

                yScale =
                    Scale.linear ( height - padding.topBottom, padding.topBottom ) ( -amplitude, amplitude )

                baseline =
                    Scale.convert yScale 0
            in
            Common.svg { width = width, height = height }
                (centreLine baseline
                    :: List.map (changeBar xScale yScale baseline) bars
                )

        _ ->
            text ""


{-| The car's racing laps in running order. The history hands them back as the
round stored them; the changes are read down the race, so the order is taken
here and not assumed.
-}
laps : LapRange -> LapHistory -> CarAt -> List Lap
laps range lapHistory item =
    Pace.racingLaps range (LapHistory.get item.metadata.carNumber lapHistory)
        |> List.sortBy .lap


{-| Each lap with the change against the racing lap before it. A lap that
matched its predecessor to the millisecond changed nothing and gets no bar.
-}
deltas : List Lap -> List ( Int, Duration )
deltas ordered =
    case ordered of
        before :: ((after :: _) as rest) ->
            List.append (change before after) (deltas rest)

        _ ->
            []


change : Lap -> Lap -> List ( Int, Duration )
change before after =
    Maybe.map2
        (\from to ->
            if to == from then
                []

            else
                [ ( after.lap, to - from ) ]
        )
        before.time
        after.time
        |> Maybe.withDefault []


amplitudeOf : List ( Int, Duration ) -> Maybe Float
amplitudeOf bars =
    bars
        |> List.map (Tuple.second >> abs >> toFloat)
        |> List.maximum


{-| The first and last lap plotted, held at least a lap apart so a single
change still has a scale to stand on.
-}
lapExtent : List ( Int, Duration ) -> Maybe ( Int, Int )
lapExtent bars =
    case ( List.map Tuple.first bars |> List.minimum, List.map Tuple.first bars |> List.maximum ) of
        ( Just first, Just last ) ->
            Just ( first, max last (first + 1) )

        _ ->
            Nothing


-- RENDER


width : Float
width =
    220


height : Float
height =
    50


padding : { left : Float, right : Float, topBottom : Float }
padding =
    { left = 4, right = 4, topBottom = 6 }


centreLine : Float -> Svg msg
centreLine baseline =
    line
        [ SvgAttr.x1 (String.fromFloat padding.left)
        , SvgAttr.x2 (String.fromFloat (width - padding.right))
        , SvgAttr.y1 (String.fromFloat baseline)
        , SvgAttr.y2 (String.fromFloat baseline)
        , SvgAttr.class "stroke-[oklch(0.5_0_0/0.3)]"
        , SvgAttr.strokeWidth "1"
        ]
        []


{-| One change: a line from the middle up where the lap was slower than the one
before it and down where it was quicker, in the colours the move arrow wears.
-}
changeBar : Scale.ContinuousScale Float -> Scale.ContinuousScale Float -> Float -> ( Int, Duration ) -> Svg msg
changeBar xScale yScale baseline ( lap, delta ) =
    let
        x =
            String.fromFloat (Scale.convert xScale (toFloat lap))

        y =
            String.fromFloat (Scale.convert yScale (toFloat delta))
    in
    line
        [ SvgAttr.x1 x
        , SvgAttr.x2 x
        , SvgAttr.y1 (String.fromFloat baseline)
        , SvgAttr.y2 y
        , SvgAttr.class (if delta < 0 then "stroke-green-500" else "stroke-red-500")
        , SvgAttr.strokeWidth "2"
        ]
        []
