module View.SectorAndLaps exposing (view, slots, pie, pieSize)

{-| Per-car "last lap and current lap, each with its sectors filled above the
time" row.

The pie is still the standings' own Lap column's: `slots` is the current
lap's sector results in the form `pie` draws.

@docs view, slots, pie, pieSize

-}

import Html exposing (Html, div, text)
import Html.Attributes exposing (class, style)
import Motorsport.Duration as Duration
import Motorsport.Lap.Performance as Performance exposing (SegmentState)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt)
import Motorsport.Sector as Sector
import Motorsport.Status as Status
import Path
import Shape
import Svg exposing (Svg, g, svg)
import Svg.Attributes as SvgAttr
import TypedSvg.Attributes exposing (viewBox)


{-| Two blocks, one per lap, in the order the race runs: last behind, current
ahead. Each stands label, sector bar, time -- the bars share a shape, so a
lap the car has just done reads against the one it is doing.
-}
view : CarAt -> Html msg
view item =
    div [ class "grid w-full grid-cols-2 gap-x-3" ]
        [ lapBlock "Last" (bar (lastSlots item)) (lastLapTimeCell item)
        , lapBlock "Current" (bar (slots item)) (currentLapTimeCell item)
        ]


lapBlock : String -> Html msg -> Html msg -> Html msg
lapBlock label sectorBar timeCell =
    div
        [ class "grid justify-items-center gap-y-px" ]
        [ labelText label
        , sectorBar
        , timeCell
        ]


currentLapTimeCell : CarAt -> Html msg
currentLapTimeCell item =
    div
        [ class "text-[13px] tabular-nums text-right"
        , style "color" (Performance.textColorOf item.currentLap.performance)
        ]
        [ text
            (if Status.hasStopped item.status then
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
        , style "color" (rated |> Maybe.map (.performance >> Performance.textColorOf) |> Maybe.withDefault "inherit")
        ]
        [ text (rated |> Maybe.map (.time >> Duration.toString) |> Maybe.withDefault "-") ]


{-| The current lap's sector results as the slots `pie` and `bar` draw. A
retired car is blank: three transparent slots, the track and nothing filled.
-}
slots : CarAt -> List ( String, Float )
slots item =
    if Status.hasRetired item.status then
        blankSlots

    else
        List.map currentSectorSlot (Sector.values item.currentLap.sectorStates)


{-| The last lap's sector results in the same slots, every one of them
complete -- the lap is run. A lap not yet turned, or a sector the feed left
blank, fills nothing.
-}
lastSlots : CarAt -> List ( String, Float )
lastSlots item =
    case item.lastLap of
        Snapshot.Completed completed ->
            List.map
                (Maybe.map (\rated -> ( Performance.toColorVariable rated.performance, 1 ))
                    >> Maybe.withDefault ( "transparent", 0 )
                )
                (Sector.values completed.sectors)

        Snapshot.NoLapYet ->
            blankSlots


blankSlots : List ( String, Float )
blankSlots =
    [ ( "transparent", 0 ), ( "transparent", 0 ), ( "transparent", 0 ) ]


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


{-| The same three slots drawn straight: three equal segments side by side,
the fill grown from the left of each over a faint full-length track -- the
pie unrolled, so the two are read by the same eye.
-}
bar : List ( String, Float ) -> Html msg
bar filled =
    div [ class "flex h-2 w-full gap-px" ]
        (List.map barSegment filled)


barSegment : ( String, Float ) -> Html msg
barSegment ( color, fraction ) =
    div [ class "relative flex-1 rounded-[1px] bg-white/10" ]
        [ if fraction > 0 then
            div
                [ class "absolute inset-y-0 left-0 rounded-[1px]"
                , style "width" (String.fromFloat (fraction * 100) ++ "%")
                , style "background-color" color
                ]
                []

          else
            text ""
        ]


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


labelText : String -> Html msg
labelText label =
    div
        [ class "text-[9px] text-muted-foreground" ]
        [ text label ]
