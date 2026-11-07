module Motorsport.Chart.LapDelta exposing (sparklineOn, sharedBounds, Bounds)

{-| The lap-to-lap change chart: each of the car's racing laps standing at its
own lap time on the vertical axis, joined to the lap before by a line -- green
where the time came down and red where it went up. The shape is the run of laps,
the height is where that run sits on the clock, and the way a stint unfolded --
building, holding, falling away -- reads at once.

The curves drawn beside one another take their scale from
[`sharedBounds`](#sharedBounds), so the same time stands at the same place on
every row of the column -- the way
[`sparklineOn`](Motorsport-Chart-LapTimeDistribution#sparklineOn) curves do, and
for the same reason.

@docs sparklineOn, sharedBounds, Bounds

-}

import Html exposing (Html, text)
import Internal.Statistics exposing (upperFenceBy)
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


{-| The scale the curves of a set share: the lap times every fence-kept lap of
the set reached, padded.
-}
type alias Bounds =
    { domain : ( Float, Float ) }


{-| The bounds the cars drawn beside one another share: the fence pooled over
every lap the set has to show and the axis drawn over the laps that survive it.
The fence is drawn tighter than the distribution chart's -- `Q3 + 0.25×IQR`
against its `Q3 + 1.5×IQR` -- because this axis is read for the run of laps
inside the class's holding pace, and every lap kept far above it costs the axis
the resolution the fine changes are seen in. LapTimeDistribution's
`pooledFence` is the reading of why the fence belongs to the set and not to
the car.

`Nothing` where none of the cars has a time at all.

-}
sharedBounds : LapHistory -> List { range : LapRange, car : CarAt } -> Maybe Bounds
sharedBounds lapHistory cars =
    let
        allTimes =
            List.concatMap (timesOf lapHistory) cars

        fence =
            upperFenceBy 0.25 allTimes

        kept =
            List.filter (\time -> time <= fence) allTimes
    in
    Statistics.extent (List.map toFloat kept)
        |> Maybe.map (\( lo, hi ) -> Bounds (padded ( lo, hi )))


{-| The racing times of one car inside its range.
-}
timesOf : LapHistory -> { range : LapRange, car : CarAt } -> List Duration
timesOf lapHistory { range, car } =
    racingLaps lapHistory car range
        |> List.filterMap .time


{-| One car's laps and the changes between them on the bounds the set shares
([`sharedBounds`](#sharedBounds)) -- so a time reads at the same place on every
curve. The fence cuts the axis and not the series: a lap the axis leaves out
stands beyond the top of the drawing, and its line is clipped by the frame. A
lap the axis leaves out below the bottom cannot happen -- the fence is an upper
bound, the quickest laps always stand inside.
-}
sparklineOn : Bounds -> LapRange -> LapHistory -> CarAt -> Html msg
sparklineOn bounds range lapHistory item =
    case changesOf (racingLaps lapHistory item range) of
        [] ->
            text ""

        changes ->
            let
                extent =
                    xExtent changes

                xScale =
                    Scale.linear ( padding.left, width - padding.right ) extent

                stroke =
                    String.fromFloat (barWidth extent)
            in
            Common.svg { width = width, height = height }
                (List.map (changeLine xScale (yScale bounds) stroke) changes)



-- SERIES


{-| One lap's change: its time and the time of the lap before it, which are the
two ends the line is drawn between.

The change is measured against the car's own previous racing lap rather than the
lap before it on the track: a lap begun in the lane or behind a procedure is no
pace to measure the next one against, and it leaves the series the way the
distribution chart beside drops it.

-}
type alias Change =
    { lap : Int
    , from : Duration
    , to : Duration
    }


{-| The car's racing laps in running order. The history hands laps back as the
round stored them; the changes are read down the race, so the order is taken here
and not assumed.
-}
racingLaps : LapHistory -> CarAt -> LapRange -> List Lap
racingLaps lapHistory item range =
    Pace.racingLaps range (LapHistory.get item.metadata.carNumber lapHistory)
        |> List.sortBy .lap


{-| Each lap with the change against the lap before it. A lap that matched its
predecessor to the millisecond changed nothing and gets no line.
-}
changesOf : List Lap -> List Change
changesOf ordered =
    case ordered of
        before :: ((after :: _) as rest) ->
            Maybe.withDefault [] (Maybe.map List.singleton (change before after))
                ++ changesOf rest

        _ ->
            []


change : Lap -> Lap -> Maybe Change
change before after =
    Maybe.map2 Tuple.pair before.time after.time
        |> Maybe.andThen
            (\( from, to ) ->
                if to == from then
                    Nothing

                else
                    Just (Change after.lap from to)
            )


{-| The horizontal domain: the laps plotted, held at least `earlyWindow` laps
wide. A car at the start of its race then stands at the stride it will run at,
packed at the left of the drawing, rather than stretched over an axis twenty
times the laps it has.
-}
xExtent : List Change -> ( Float, Float )
xExtent changes =
    let
        laps =
            List.map .lap changes

        first =
            List.minimum laps |> Maybe.withDefault 0

        last =
            List.maximum laps |> Maybe.withDefault 1
    in
    ( toFloat first, toFloat (max last (first + earlyWindow)) )


{-| How many laps the axis is at least this wide.
-}
earlyWindow : Int
earlyWindow =
    20


{-| The shared time axis, padded so the quickest lap of the set stands above
the bottom and the slowest below the top.
-}
yScale : Bounds -> Scale.ContinuousScale Float
yScale bounds =
    Scale.linear ( height - padding.topBottom, padding.topBottom ) bounds.domain


{-| The room a padded axis stands in: a tenth of the span and a millisecond, so
a set with no spread at all still has an axis.
-}
padded : ( Float, Float ) -> ( Float, Float )
padded ( lo, hi ) =
    let
        margin =
            (hi - lo) * 0.1 + 1
    in
    ( lo - margin, hi + margin )



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


{-| The room a lap's line may take: the drawing's width divided by the laps
standing in the window, of which the line claims most -- one drawn at the full
stride would weld the laps into one band, and one thinner than a pixel reads as
nothing, so the share is held between those, and under a twentieth of the
drawing where it would be a wall rather than a line.
-}
barWidth : ( Float, Float ) -> Float
barWidth ( first, last ) =
    let
        stride =
            (width - padding.left - padding.right) / (last - first)
    in
    clamp 1 (width / 20) (stride * 0.75)


{-| One change: a line from the previous lap's time down to this lap's where
the time came down, up where it went up, in the colours the move arrow wears.
-}
changeLine : Scale.ContinuousScale Float -> Scale.ContinuousScale Float -> String -> Change -> Svg msg
changeLine xScale ys stroke { lap, from, to } =
    let
        x =
            String.fromFloat (Scale.convert xScale (toFloat lap))
    in
    line
        [ SvgAttr.x1 x
        , SvgAttr.x2 x
        , SvgAttr.y1 (String.fromFloat (Scale.convert ys (toFloat from)))
        , SvgAttr.y2 (String.fromFloat (Scale.convert ys (toFloat to)))
        , SvgAttr.class
            (if to < from then
                "stroke-green-500"

             else
                "stroke-red-500"
            )
        , SvgAttr.strokeWidth stroke
        ]
        []
