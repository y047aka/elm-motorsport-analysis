module Motorsport.Widget.SectorAndLaps exposing (view)

{-| Per-car "sector progress pie + Current lap + Last lap" row,
shared by SelectedCarsStrip and Compare.

@docs view

-}

import Html.Styled exposing (Html, div, text)
import Html.Styled.Attributes exposing (class, style)
import Motorsport.Duration as Duration
import Motorsport.Lap.Performance as Performance exposing (SegmentState)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt)
import Motorsport.Sector as Sector
import Motorsport.Status as Status
import Path.Styled as Path
import Shape
import Svg.Styled exposing (Svg, g, svg)
import Svg.Styled.Attributes as SvgAttr
import TypedSvg.Styled.Attributes exposing (viewBox)


{-| The pie shows sector progress of the current lap, so it shares a column
with Current; the layout is a balanced 50/50 grid of `pie + Current` | `Last`.
-}
view : CarAt -> Html msg
view item =
    div
        [ class "grid grid-cols-[1fr_1fr] place-items-center gap-x-2" ]
        [ div
            [ class "grid w-fit grid-cols-[auto_auto] items-center gap-x-2" ]
            [ currentSectorPie item
            , currentLapBlock item
            ]
        , lastLapBlock item
        ]


currentLapBlock : CarAt -> Html msg
currentLapBlock item =
    lapBlock "Current" (currentLapTimeCell item)


lastLapBlock : CarAt -> Html msg
lastLapBlock item =
    lapBlock "Last" (lastLapTimeCell item)


lapBlock : String -> Html msg -> Html msg
lapBlock label timeCell =
    div
        [ class "grid place-items-center gap-y-px" ]
        [ labelText label
        , timeCell
        ]


currentLapTimeCell : CarAt -> Html msg
currentLapTimeCell item =
    div
        [ class "text-[13px] tabular-nums text-right"
        , style "color" (performanceColor item.currentLap.performance)
        ]
        [ text
            (if Status.hasRetired item.status then
                "-"

             else
                Duration.toString item.currentLap.elapsed
            )
        ]


lastLapTimeCell : CarAt -> Html msg
lastLapTimeCell item =
    let
        rated =
            case item.lastLap of
                Snapshot.Completed completed ->
                    completed.rated

                Snapshot.NoLapYet ->
                    Nothing
    in
    div
        [ class "text-[13px] tabular-nums text-right"
        , style "color" (rated |> Maybe.map (.performance >> performanceColor) |> Maybe.withDefault "inherit")
        ]
        [ text (rated |> Maybe.map (.time >> Duration.toString) |> Maybe.withDefault "-") ]


performanceColor : Performance.PerformanceLevel -> String
performanceColor performance =
    if Performance.isStandard performance then
        "inherit"

    else
        Performance.toColorVariable performance


{-| Small three-slot donut showing sector results of the current lap.
The in-progress sector is filled white up to its progress; completed
sectors are filled with their performance color.
-}
currentSectorPie : CarAt -> Html msg
currentSectorPie item =
    if Status.hasRetired item.status then
        emptyPie

    else
        sectorPie (List.map currentSectorSlot (Sector.values item.currentLap.sectorStates))


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
            -- A sector the source data has no time for has no rating to colour it by.
            ( rated
                |> Maybe.map .performance
                |> Maybe.withDefault Performance.Standard
                |> Performance.toColorVariable
            , 1
            )


{-| Draw three slots as 120° donut arcs. Each element is
`(fill color, fill fraction 0..1)`; the fill grows from the slot start,
over a faint full-length track.
-}
sectorPie : List ( String, Float ) -> Html msg
sectorPie slots =
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
            (slots |> List.indexedMap sectorSlot |> List.concat)
        ]


emptyPie : Html msg
emptyPie =
    sectorPie [ ( "transparent", 0 ), ( "transparent", 0 ), ( "transparent", 0 ) ]


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


labelText : String -> Html msg
labelText label =
    div
        [ class "text-[9px] opacity-60" ]
        [ text label ]
