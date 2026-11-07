module View.SectorPie exposing (pie, pieSize, slots)

{-| The standings' Lap column: the current lap's sector results on a
three-slot donut.

@docs pie, pieSize, slots

-}

import Html exposing (Html)
import Motorsport.Lap.Performance as Performance exposing (SegmentState)
import Motorsport.Race.Snapshot exposing (CarAt)
import Motorsport.Sector as Sector
import Motorsport.Status as Status
import Path
import Shape
import Svg exposing (Svg, g, svg)
import Svg.Attributes as SvgAttr
import TypedSvg.Attributes exposing (viewBox)


{-| The current lap's sector results as the slots `pie` draws. A retired car is
a blank donut: three transparent slots, the track and nothing filled.
-}
slots : CarAt -> List ( String, Float )
slots item =
    if Status.hasRetired item.status then
        [ ( "transparent", 0 ), ( "transparent", 0 ), ( "transparent", 0 ) ]

    else
        List.map currentSectorSlot (Sector.values item.currentLap.sectorStates)


{-| Convert one sector into `(fill color, fill fraction 0..1)`:
white partial fill while in progress, full performance color once completed.
A sector the car has not reached fills nothing, so its colour never shows.
-}
currentSectorSlot : SegmentState -> ( String, Float )
currentSectorSlot state =
    case state of
        Performance.NotEntered ->
            ( "oklch(1 0 0)", 0 )

        Performance.InProgress progress ->
            ( "oklch(1 0 0)", progress )

        Performance.Completed rated ->
            ( Performance.colorOf (Maybe.map .performance rated), 1 )


{-| Draw three slots as 120° donut arcs. Each element is
`(fill color, fill fraction 0..1)`; the fill grows from the slot start,
over a faint full-length track.
-}
pie : List ( String, Float ) -> Html msg
pie filled =
    svg
        [ SvgAttr.width (String.fromFloat pieSize ++ "px")
        , SvgAttr.height (String.fromFloat pieSize ++ "px")
        , SvgAttr.style "display: block;"
        , viewBox 0 0 pieSize pieSize
        ]
        [ g
            [ SvgAttr.transform
                ("translate(" ++ String.fromFloat (pieSize / 2) ++ " " ++ String.fromFloat (pieSize / 2) ++ ")")
            ]
            (filled |> List.indexedMap sectorSlot |> List.concat)
        ]


sectorSlot : Int -> ( String, Float ) -> List (Svg msg)
sectorSlot index ( color, fraction ) =
    let
        slot =
            2 * pi / 3

        arc fillFraction =
            Shape.arc
                { innerRadius = pieInner
                , outerRadius = pieOuter
                , cornerRadius = 1
                , startAngle = toFloat index * slot + pieGap / 2
                , endAngle = toFloat index * slot + pieGap / 2 + (slot - pieGap) * fillFraction
                , padAngle = 0
                , padRadius = 0
                }

        track =
            Path.element (arc 1) [ SvgAttr.fill "hsl(0 0% 100% / 0.12)" ]
    in
    if fraction <= 0 then
        [ track ]

    else
        [ track, Path.element (arc fraction) [ SvgAttr.fill color ] ]


pieSize : Float
pieSize =
    30


pieOuter : Float
pieOuter =
    13


pieInner : Float
pieInner =
    6.5


{-| Gap between slots, in radians.
-}
pieGap : Float
pieGap =
    0.12
