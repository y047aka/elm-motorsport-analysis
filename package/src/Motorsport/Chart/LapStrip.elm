module Motorsport.Chart.LapStrip exposing
    ( Scale
    , strip
    )

{-| A car's laps as dots over a stretch of the race: one dot per lap, at the
time that lap took. No line joins them.

A lap is a separate reading, not a point on a curve, and the laps that are
missing mean as much as the ones that are there -- the lap a car spent in the
lane is off this strip, and a line drawn across the gap would say the car went
as fast through the pits as it did on the road.

@docs Scale
@docs strip

-}

import Motorsport.Duration exposing (Duration)
import Motorsport.Lap exposing (Lap)
import Motorsport.LapRange exposing (LapRange)
import Scale
import Svg exposing (Svg)
import Svg.Attributes as SvgAttr


{-| The scale one strip is drawn against: the laps spread across the width and
the two lap times spread across the height.

A caller gives the scale of several cars together rather than each strip its
own, which is the whole reason a strip means anything: a strip scaled to its
own quickest and slowest lap draws a car saving fuel with as steep a shape as a
car on a push, and the two are opposite news.

-}
type alias Scale =
    { laps : LapRange
    , quickest : Duration
    , slowest : Duration
    }


{-| The dots in the car's colour. Laps the source has no time for are not
drawn, rather than drawn as a dot at the bottom of the scale.

Laps outside `Scale` fall on the top or bottom row rather than off the strip:
a scale is drawn from the few cars a board shows, and a car that joins the
board with a lap none of them ran should show that it did.

-}
strip : { width : Float, height : Float } -> Scale -> String -> List Lap -> Svg msg
strip size scale color laps =
    let
        xScale =
            Scale.linear ( 2, size.width - 2 ) (spread (toFloat scale.laps.first) (toFloat scale.laps.last))

        yScale =
            Scale.linear ( 2, size.height - 2 ) (spread (toFloat scale.quickest) (toFloat scale.slowest))

        dot lap =
            Maybe.map
                (\time ->
                    Svg.circle
                        [ SvgAttr.cx (spot (Scale.convert xScale (toFloat lap.lap)))
                        , SvgAttr.cy (spot (clamp 0 size.height (Scale.convert yScale (toFloat time))))
                        , SvgAttr.r "1.4"
                        , SvgAttr.fill color
                        ]
                        []
                )
                lap.time
    in
    Svg.svg
        [ SvgAttr.width (px size.width)
        , SvgAttr.height (px size.height)
        , SvgAttr.viewBox ("0 0 " ++ px size.width ++ " " ++ px size.height)
        ]
        (List.filterMap dot laps)


{-| A scale that starts and ends at one value maps every point to NaN and the
drawing vanishes; spreading it by half either side leaves the flat thing it is.
-}
spread : Float -> Float -> ( Float, Float )
spread low high =
    if low == high then
        ( low - 0.5, high + 0.5 )

    else
        ( low, high )


{-| Kept to a tenth of a pixel, which is finer than a dot and shorter than the
whole float would write.
-}
spot : Float -> String
spot =
    (*) 10 >> round >> toFloat >> (*) 0.1 >> String.fromFloat


px : Float -> String
px n =
    String.fromFloat n ++ "px"
