module Motorsport.Chart.LapDelta exposing (sparkline)

{-| The lap-to-lap change chart: each of the car's racing laps standing at its
own lap time on the vertical axis, joined to the lap before by a line -- green
where the time came down and red where it went up. The shape is the run of laps,
the height is where that run sits on the clock, and the way a stint unfolded --
building, holding, falling away -- reads at once.

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
import Statistics
import Svg exposing (Svg, line)
import Svg.Attributes as SvgAttr


{-| One car's laps and the changes between them at card size: each lap stands
where its time stands, a line reaching to the time of the racing lap before it.
Nothing where the window holds fewer than two timed laps to have a change
between.
-}
sparkline : LapRange -> LapHistory -> CarAt -> Html msg
sparkline range lapHistory item =
    let
        changes =
            changesOf (laps range lapHistory item)
    in
    case ( timeDomain changes, lapExtent changes ) of
        ( Just domain, Just ( first, last ) ) ->
            let
                xScale =
                    Scale.linear ( padding.left, width - padding.right ) ( toFloat first, toFloat last )

                yScale =
                    Scale.linear ( height - padding.topBottom, padding.topBottom ) domain
            in
            Common.svg { width = width, height = height }
                (List.map (changeLine xScale yScale) changes)

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


{-| One lap's change: its time and the time of the racing lap before it, which
are the two ends the line is drawn between.
-}
type alias Change =
    { lap : Int
    , from : Duration
    , to : Duration
    }


{-| Each lap with the change against the racing lap before it. A lap that
matched its predecessor to the millisecond changed nothing and gets no line.
-}
changesOf : List Lap -> List Change
changesOf ordered =
    case ordered of
        before :: ((after :: _) as rest) ->
            List.append (change before after) (changesOf rest)

        _ ->
            []


change : Lap -> Lap -> List Change
change before after =
    Maybe.map2
        (\from to ->
            if to == from then
                []

            else
                [ Change after.lap from to ]
        )
        before.time
        after.time
        |> Maybe.withDefault []


{-| The vertical domain: every time the lines touch, padded, so the quickest
lap of the window stands at the bottom and the slowest at the top.
-}
timeDomain : List Change -> Maybe ( Float, Float )
timeDomain changes =
    List.concatMap (\c -> [ toFloat c.from, toFloat c.to ]) changes
        |> Statistics.extent
        |> Maybe.map
            (\( lo, hi ) ->
                let
                    margin =
                        (hi - lo) * 0.1 + 1
                in
                ( lo - margin, hi + margin )
            )


{-| The first and last lap plotted, held at least a lap apart so a single
change still has a scale to stand on.
-}
lapExtent : List Change -> Maybe ( Int, Int )
lapExtent changes =
    case ( List.map .lap changes |> List.minimum, List.map .lap changes |> List.maximum ) of
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


{-| One change: a line from the time of the lap before down to this lap's where
the time came down, up where it went up, in the colours the move arrow wears.
-}
changeLine : Scale.ContinuousScale Float -> Scale.ContinuousScale Float -> Change -> Svg msg
changeLine xScale yScale { lap, from, to } =
    let
        x =
            String.fromFloat (Scale.convert xScale (toFloat lap))
    in
    line
        [ SvgAttr.x1 x
        , SvgAttr.x2 x
        , SvgAttr.y1 (String.fromFloat (Scale.convert yScale (toFloat from)))
        , SvgAttr.y2 (String.fromFloat (Scale.convert yScale (toFloat to)))
        , SvgAttr.class (if to < from then "stroke-green-500" else "stroke-red-500")
        , SvgAttr.strokeWidth "2"
        ]
        []
