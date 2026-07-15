module Motorsport.Widget.SectorAndLaps exposing (view)

{-| Per-car "sector progress pie + Current lap + Last lap" row,
shared by SelectedCarsStrip and Compare.

@docs view

-}

import Css exposing (batch, num, opacity, property)
import Html.Styled exposing (Html, div, text)
import Html.Styled.Attributes exposing (css)
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Car as Car
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap.Performance as Performance exposing (performanceLevel)
import Motorsport.Sector exposing (Sector(..))
import Motorsport.ViewModel.Standings exposing (SectorProgress, Entry)
import Path.Styled as Path
import Shape
import Svg.Styled exposing (Svg, g, svg)
import Svg.Styled.Attributes as SvgAttr
import TypedSvg.Styled.Attributes exposing (viewBox)


{-| The pie shows sector progress of the current lap, so it shares a column
with Current; the layout is a balanced 50/50 grid of `pie + Current` | `Last`.
-}
view : Analysis -> Entry -> Html msg
view analysis item =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "1fr 1fr"
            , property "place-items" "center"
            , property "column-gap" "8px"
            ]
        ]
        [ div
            [ css
                [ property "display" "grid"
                , property "width" "fit-content"
                , property "grid-template-columns" "auto auto"
                , property "align-items" "center"
                , property "column-gap" "8px"
                ]
            ]
            [ currentSectorPie analysis item
            , currentLapBlock analysis item
            ]
        , lastLapBlock item
        ]


currentLapBlock : Analysis -> Entry -> Html msg
currentLapBlock analysis item =
    lapBlock "Current" (currentLapTimeCell analysis item)


lastLapBlock : Entry -> Html msg
lastLapBlock item =
    lapBlock "Last" (lastLapTimeCell item)


lapBlock : String -> Html msg -> Html msg
lapBlock label timeCell =
    div
        [ css
            [ property "display" "grid"
            , property "place-items" "center"
            , property "row-gap" "1px"
            ]
        ]
        [ labelText label
        , timeCell
        ]


currentLapTimeCell : Analysis -> Entry -> Html msg
currentLapTimeCell analysis item =
    let
        colorStyle =
            case item.currentLapBest of
                Just best ->
                    performanceLevel
                        { time = item.currentLapElapsed, personalBest = best, fastest = analysis.fastestLapTime }
                        |> applyPerformanceColor

                Nothing ->
                    batch []
    in
    div
        [ css
            [ property "font-size" "13px"
            , property "font-variant-numeric" "tabular-nums"
            , property "text-align" "right"
            , colorStyle
            ]
        ]
        [ text
            (if Car.hasRetired item.status then
                "-"

             else
                Duration.toString item.currentLapElapsed
            )
        ]


lastLapTimeCell : Entry -> Html msg
lastLapTimeCell item =
    div
        [ css
            [ property "font-size" "13px"
            , property "font-variant-numeric" "tabular-nums"
            , property "text-align" "right"
            , case item.lastLap of
                Just { performance } ->
                    applyPerformanceColor performance

                Nothing ->
                    batch []
            ]
        ]
        [ text (item.lastLap |> Maybe.map (.time >> Duration.toString) |> Maybe.withDefault "-") ]


applyPerformanceColor : Performance.PerformanceLevel -> Css.Style
applyPerformanceColor performance =
    if Performance.isStandard performance then
        batch []

    else
        property "color" (Performance.toColorVariable performance)


{-| Small three-slot donut showing sector results of the current lap.
The in-progress sector is filled white up to its progress; completed
sectors are filled with their performance color.
-}
currentSectorPie : Analysis -> Entry -> Html msg
currentSectorPie analysis item =
    case ( item.currentLapSectors, Car.hasRetired item.status ) of
        ( Just sectors, False ) ->
            let
                ( s1p, s2p, s3p ) =
                    sectorProgressTriplet item.sector
            in
            sectorPie
                [ currentSectorSlot { time = sectors.sector_1, personalBest = sectors.s1_best, fastest = analysis.sector_1_fastest, progress = s1p }
                , currentSectorSlot { time = sectors.sector_2, personalBest = sectors.s2_best, fastest = analysis.sector_2_fastest, progress = s2p }
                , currentSectorSlot { time = sectors.sector_3, personalBest = sectors.s3_best, fastest = analysis.sector_3_fastest, progress = s3p }
                ]

        _ ->
            emptyPie


sectorProgressTriplet : Maybe SectorProgress -> ( Float, Float, Float )
sectorProgressTriplet sectorProgress =
    case sectorProgress of
        Just { sector, progress } ->
            case sector of
                S1 ->
                    ( progress, 0, 0 )

                S2 ->
                    ( 100, progress, 0 )

                S3 ->
                    ( 100, 100, progress )

        Nothing ->
            ( 100, 100, 100 )


{-| Convert one sector into `(fill color, fill fraction 0..1)`:
white partial fill while in progress, full performance color once completed.
-}
currentSectorSlot : { time : Duration, personalBest : Duration, fastest : Duration, progress : Float } -> ( String, Float )
currentSectorSlot sector =
    if sector.progress < 100 then
        ( "oklch(1 0 0)", sector.progress / 100 )

    else
        ( performanceLevel { time = sector.time, personalBest = sector.personalBest, fastest = sector.fastest }
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
        , SvgAttr.css [ Css.property "display" "block" ]
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
        [ css
            [ property "font-size" "9px"
            , opacity (num 0.6)
            ]
        ]
        [ text label ]
