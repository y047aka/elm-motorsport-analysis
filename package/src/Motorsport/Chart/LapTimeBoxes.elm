module Motorsport.Chart.LapTimeBoxes exposing (view)

{-| The field's lap times as they ran over the race, one chart per class:
each chart stands one box-and-whisker per block of race laps, the box the
quartiles of that class's timed laps in the block, the whiskers the furthest
laps within a `Q3 + 1.5×IQR` reach -- a dot for every lap beyond that.

A box is green where its median came down from the block before and red where
it went up: the reading is the class's pace trend, lap block to lap block. The
first block has no before and stands grey, so does one that repeated its
median to the millisecond.

`lapsRun` is how far the leader has come at the clock, and a lap joins a
block when the leader has completed its own; the blocks stand in race order
from the left. Every class shares the horizontal -- the same block of laps
lines up from chart to chart -- while each chart scales its own vertical, a
class being no position against another's pace.

Dots beyond the axis stand outside the drawing and are clipped by the frame --
the reading the lap-delta sparkline beside shares.

-}

import Html exposing (Html, div, text)
import Html.Attributes exposing (class)
import Internal.Statistics as Statistics
import Motorsport.Chart.Common as Common
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap
import Motorsport.Race.Car exposing (Car)
import Motorsport.Wec.Class as Class exposing (Class)
import Scale exposing (defaultBandConfig)
import Svg exposing (Svg)
import Svg.Attributes as SvgAttr


{-| One block's reading: the quartiles and the whisker ends -- which are
laps, not fences.
-}
type alias Box =
    { q1 : Duration
    , median : Duration
    , q3 : Duration
    , low : Duration
    , high : Duration
    , outliers : List Duration
    }


{-| The field's race so far: the classes that are running, each with its
chart, in the order a classification lists them.
-}
view : Int -> List Car -> Html msg
view lapsRun raceCars =
    let
        blockSize =
            max 1 (ceilingDivide lapsRun maxBlocks)

        running =
            raceCars
                |> List.map (.metadata >> .class)
                |> List.foldl
                    (\class classes ->
                        if List.member class classes then
                            classes

                        else
                            class :: classes
                    )
                    []
                |> List.sortWith Class.compare
    in
    if List.isEmpty running then
        text ""

    else
        div [ class "grid w-full gap-y-1" ]
            (List.map (classChart lapsRun blockSize raceCars) running)


classChart : Int -> Int -> List Car -> Class -> Html msg
classChart lapsRun blockSize raceCars class =
    let
        boxes =
            raceCars
                |> List.filter (\car -> car.metadata.class == class)
                |> timedLapsTo lapsRun blockSize
                |> blocks (ceilingDivide lapsRun blockSize)
                |> List.map boxOf
    in
    case boxes of
        [] ->
            text ""

        _ ->
            drawChart class boxes


timedLapsTo : Int -> Int -> List Car -> List ( Int, Duration )
timedLapsTo lapsRun blockSize raceCars =
    raceCars
        |> List.concatMap
            (\car ->
                car.laps
                    |> List.filter (\lap -> lap.lap <= lapsRun && Lap.isRacingLap lap)
                    |> List.filterMap
                        (\lap ->
                            Maybe.map (\time -> ( (lap.lap - 1) // blockSize, time )) lap.time
                        )
            )


{-| The blocks in race order, empty blocks left out -- a class that made no
timed lap of a block has no box to draw for it.
-}
blocks : Int -> List ( Int, Duration ) -> List (List Duration)
blocks numBlocks byBlock =
    List.filterMap
        (\block ->
            byBlock
                |> List.filter (\( b, _ ) -> b == block)
                |> List.map Tuple.second
                |> (\times ->
                        if List.isEmpty times then
                            Nothing

                        else
                            Just times
                   )
        )
        (List.range 0 (numBlocks - 1))


boxOf : List Duration -> Box
boxOf times =
    let
        sorted =
            List.sort times

        quantile q =
            Statistics.quantile q sorted |> Maybe.withDefault (List.minimum sorted |> Maybe.withDefault 0)

        q1 =
            quantile 0.25

        q3 =
            quantile 0.75

        reach =
            1.5 * toFloat (q3 - q1)

        topFence =
            toFloat q3 + reach

        lowFence =
            toFloat q1 - reach
    in
    { q1 = q1
    , median = quantile 0.5
    , q3 = q3
    , low =
        times |> List.filter (\t -> toFloat t >= lowFence) |> List.minimum |> Maybe.withDefault q1
    , high =
        times |> List.filter (\t -> toFloat t <= topFence) |> List.maximum |> Maybe.withDefault q3
    , outliers =
        List.filter (\t -> toFloat t > topFence || toFloat t < lowFence) times
    }


{-| The box, its whiskers and the laps they miss, in the colour the median
toward the block before earned; and beside it, how many the axis left out.
-}
drawChart : Class -> List Box -> Html msg
drawChart class boxes =
    let
        n =
            List.length boxes

        xScale =
            Scale.band { defaultBandConfig | paddingInner = 0.15, paddingOuter = 0.1 }
                ( padding.left, width - padding.right )
                (List.range 0 (n - 1))

        band =
            Scale.bandwidth xScale

        boxWidth =
            max 1 (band * 0.62)

        domain =
            padded
                ( List.map .low boxes |> List.minimum |> Maybe.withDefault 0
                , List.map .high boxes |> List.maximum |> Maybe.withDefault 1
                )

        yScale =
            Scale.linear ( height - padding.bottom, label.bottom ) ( toFloat (Tuple.first domain), toFloat (Tuple.second domain) )

        centre i =
            Scale.convert xScale i + band / 2

        y t =
            Scale.convert yScale (toFloat t)
    in
    Common.svg { width = width, height = height }
        ([ Svg.text_
            [ SvgAttr.x (String.fromFloat padding.left)
            , SvgAttr.y "9"
            , SvgAttr.fill (Class.toColor class)
            , SvgAttr.fontSize "8"
            , SvgAttr.fontWeight "bold"
            ]
            [ Svg.text (Class.toString class) ]
         ]
            ++ List.indexedMap (box yScale centre boxWidth y) (List.map2 Tuple.pair (Nothing :: List.map Just (List.map .median boxes)) boxes)
        )


{-| Whether this box's median came down, went up, or held -- the block before
having nothing to have come from.
-}
tone : Maybe Duration -> Duration -> { fill : String, median : String }
tone previous median =
    case previous of
        Nothing ->
            muted

        Just before ->
            if median < before then
                { fill = "fill-green-500/25", median = "stroke-green-500" }

            else if median > before then
                { fill = "fill-red-500/25", median = "stroke-red-500" }

            else
                muted


muted : { fill : String, median : String }
muted =
    { fill = "fill-muted-foreground/25", median = "stroke-muted-foreground" }


box :
    Scale.ContinuousScale Float
    -> (Int -> Float)
    -> Float
    -> (Duration -> Float)
    -> Int
    -> ( Maybe Duration, Box )
    -> Svg msg
box yScale centre boxWidth y index ( previous, b ) =
    let
        x =
            centre index

        half =
            boxWidth / 2

        shade =
            tone previous b.median
    in
    Svg.g [ SvgAttr.class "stroke-muted-foreground" ]
        ([ segment x (y b.low) x (y b.high)
         , segment (x - half * 0.6) (y b.high) (x + half * 0.6) (y b.high)
         , segment (x - half * 0.6) (y b.low) (x + half * 0.6) (y b.low)
         , Svg.rect
            [ SvgAttr.class shade.fill
            , SvgAttr.x (String.fromFloat (x - half))
            , SvgAttr.y (String.fromFloat (y b.q3))
            , SvgAttr.width (String.fromFloat boxWidth)
            , SvgAttr.height (String.fromFloat (max 1 (y b.q1 - y b.q3)))
            ]
            []
         , Svg.line
            [ SvgAttr.class shade.median
            , SvgAttr.x1 (String.fromFloat (x - half))
            , SvgAttr.y1 (String.fromFloat (y b.median))
            , SvgAttr.x2 (String.fromFloat (x + half))
            , SvgAttr.y2 (String.fromFloat (y b.median))
            , SvgAttr.strokeWidth "1.5"
            ]
            []
         ]
            ++ List.map (dot x y) b.outliers
        )


dot : Float -> (Duration -> Float) -> Duration -> Svg msg
dot x y time =
    Svg.circle
        [ SvgAttr.cx (String.fromFloat x)
        , SvgAttr.cy (String.fromFloat (y time))
        , SvgAttr.r "1"
        , SvgAttr.class "fill-muted-foreground/50"
        ]
        []


segment : Float -> Float -> Float -> Float -> Svg msg
segment x1 y1 x2 y2 =
    Svg.line
        [ SvgAttr.x1 (String.fromFloat x1)
        , SvgAttr.y1 (String.fromFloat y1)
        , SvgAttr.x2 (String.fromFloat x2)
        , SvgAttr.y2 (String.fromFloat y2)
        , SvgAttr.strokeWidth "1"
        ]
        []



-- SPLITTING --


maxBlocks : Int
maxBlocks =
    30


{-| The room a padded axis stands in: a tenth of the span and a second, so a
race with no spread at all still has boxes to read.
-}
padded : ( Int, Int ) -> ( Int, Int )
padded ( lo, hi ) =
    let
        room =
            toFloat (hi - lo) / 10 + 1000
    in
    ( lo - round room, hi + round room )


ceilingDivide : Int -> Int -> Int
ceilingDivide a b =
    if b <= 0 then
        1

    else
        -(-a // b)


width : Float
width =
    300


height : Float
height =
    66


padding : { left : Float, right : Float, bottom : Float }
padding =
    { left = 3, right = 3, bottom = 5 }


label : { bottom : Float }
label =
    { bottom = 14 }
