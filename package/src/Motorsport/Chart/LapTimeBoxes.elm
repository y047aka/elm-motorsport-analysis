module Motorsport.Chart.LapTimeBoxes exposing (view)

{-| The field's lap times as they ran over the race: one box-and-whisker per
block of race laps, the box the quartiles of every car's timed laps in that
block, the whiskers the furthest laps within a whisker's reach of it -- a
`Q3 + 1.5×IQR` reach, the usual one -- and a dot for every lap beyond that.

Two readings the box carries are worth naming: the whole field shares each one,
classes and all, so the interquartile range holds the classes apart as well as
the field's own spread; and no lap is left out of its block for running under
a procedure -- a caution bunches the field and the blocks of the race say so.

The boxes grow with the leader: `lapsRun` is how far the leader has come at
the clock, and a lap joins a block when the leader has completed its own.

Dots beyond the axis stand outside the drawing and are clipped by the frame --
the reading the lap-delta sparkline beside shares.

-}

import Html exposing (Html, text)
import Internal.Statistics as Statistics
import Motorsport.Chart.Common as Common
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap
import Motorsport.Race.Car exposing (Car)
import Scale exposing (defaultBandConfig)
import Svg exposing (Svg)
import Svg.Attributes as SvgAttr


{-| One block's reading: the quartiles, the whisker ends -- which are laps,
not fences -- and the laps neither whisker reaches.
-}
type alias Box =
    { q1 : Duration
    , median : Duration
    , q3 : Duration
    , low : Duration
    , high : Duration
    , outliers : List Duration
    }


{-| The field's race so far, in blocks of at most `maxBlocks` boxes.
-}
view : Int -> List Car -> Html msg
view lapsRun raceCars =
    let
        blockSize =
            max 1 (ceilingDivide lapsRun maxBlocks)

        boxes =
            raceCars
                |> timedLapsTo lapsRun
                |> List.map (\( lapNumber, time ) -> ( (lapNumber - 1) // blockSize, time ))
                |> List.sortBy Tuple.first
                |> blocksOf
                |> List.map boxOf
    in
    case boxes of
        [] ->
            text ""

        _ ->
            draw boxes


{-| Every timed racing lap of the field up to the leader's, newest blocks
first not being the point -- in race order, which is the block order.
-}
timedLapsTo : Int -> List Car -> List ( Int, Duration )
timedLapsTo lapsRun raceCars =
    raceCars
        |> List.concatMap
            (\car ->
                car.laps
                    |> List.filter (\lap -> lap.lap <= lapsRun && Lap.isRacingLap lap)
                    |> List.filterMap (\lap -> Maybe.map (\time -> ( lap.lap, time )) lap.time)
            )


blocksOf : List ( Int, Duration ) -> List (List Duration)
blocksOf byBlock =
    List.foldl
        (\( block, time ) acc ->
            case acc of
                ( thisBlock, times ) :: rest ->
                    if thisBlock == block then
                        ( block, time :: times ) :: rest

                    else
                        ( block, [ time ] ) :: acc

                [] ->
                    [ ( block, [ time ] ) ]
        )
        []
        byBlock
        |> List.map Tuple.second


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


draw : List Box -> Html msg
draw boxes =
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
            Scale.linear ( height - padding.bottom, padding.top ) ( toFloat (Tuple.first domain), toFloat (Tuple.second domain) )

        centre i =
            Scale.convert xScale i + band / 2

        y t =
            Scale.convert yScale (toFloat t)
    in
    Common.svg { width = width, height = height }
        (List.indexedMap (box yScale centre boxWidth y) boxes)


box :
    Scale.ContinuousScale Float
    -> (Int -> Float)
    -> Float
    -> (Duration -> Float)
    -> Int
    -> Box
    -> Svg msg
box yScale centre boxWidth y index b =
    let
        x =
            centre index

        half =
            boxWidth / 2
    in
    Svg.g []
        ([ segment x (y b.low) x (y b.high) "hsl(0 0% 100% / 0.55)" 1
         , segment (x - half * 0.6) (y b.high) (x + half * 0.6) (y b.high) "hsl(0 0% 100% / 0.55)" 1
         , segment (x - half * 0.6) (y b.low) (x + half * 0.6) (y b.low) "hsl(0 0% 100% / 0.55)" 1
         , Svg.rect
            [ SvgAttr.x (String.fromFloat (x - half))
            , SvgAttr.y (String.fromFloat (y b.q3))
            , SvgAttr.width (String.fromFloat boxWidth)
            , SvgAttr.height (String.fromFloat (max 1 (y b.q1 - y b.q3)))
            , SvgAttr.fill "hsl(0 0% 100% / 0.16)"
            ]
            []
         , segment (x - half) (y b.median) (x + half) (y b.median) "hsl(0 0% 100% / 0.9)" 1.5
         ]
            ++ List.map (dot x y) b.outliers
        )


dot : Float -> (Duration -> Float) -> Duration -> Svg msg
dot x y time =
    Svg.circle
        [ SvgAttr.cx (String.fromFloat x)
        , SvgAttr.cy (String.fromFloat (y time))
        , SvgAttr.r "1"
        , SvgAttr.fill "hsl(0 0% 100% / 0.45)"
        ]
        []


segment : Float -> Float -> Float -> Float -> String -> Float -> Svg msg
segment x1 y1 x2 y2 color thickness =
    Svg.line
        [ SvgAttr.x1 (String.fromFloat x1)
        , SvgAttr.y1 (String.fromFloat y1)
        , SvgAttr.x2 (String.fromFloat x2)
        , SvgAttr.y2 (String.fromFloat y2)
        , SvgAttr.stroke color
        , SvgAttr.strokeWidth (String.fromFloat thickness)
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
    110


padding : { left : Float, right : Float, top : Float, bottom : Float }
padding =
    { left = 3, right = 3, top = 5, bottom = 5 }
