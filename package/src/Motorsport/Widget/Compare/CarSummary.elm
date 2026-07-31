module Motorsport.Widget.Compare.CarSummary exposing (carSummary, placeholderCard)

{-| Per-car summary card (header + standings strip + lap-time panel) for the
Compare widget, plus the placeholder that fills an unselected slot.

@docs carSummary, placeholderCard

-}

import Css exposing (num, opacity, property)
import Html.Styled exposing (Html, div, text)
import Html.Styled.Attributes exposing (css)
import Motorsport.Chart.LapTimeDistribution as LapTimeDistribution
import Motorsport.Driver as Driver
import Motorsport.Gap as Gap
import Motorsport.Status exposing (Status(..))
import Motorsport.ViewModel.LapHistory exposing (LapHistory)
import Motorsport.ViewModel.Standings exposing (Entry)
import Motorsport.Widget.CarNumberBadge as CarNumberBadge
import Motorsport.Widget.Compare.Distribution as Distribution
import Motorsport.Widget.Compare.Style exposing (glassPanel, panelLabel)
import Motorsport.Widget.SectorAndLaps as SectorAndLaps


{-| Subtle placeholder filling an unselected slot. Nudges toward the selector above.
-}
placeholderCard : Html msg
placeholderCard =
    div
        [ css
            [ property "display" "grid"
            , property "place-items" "center"
            , property "min-height" "100px"
            , property "border" "1px dashed hsl(0 0% 100% / 0.15)"
            , property "border-radius" "8px"
            , property "font-size" "11px"
            , property "color" "hsl(0 0% 100% / 0.35)"
            ]
        ]
        [ text "車両を追加" ]


carSummary : Maybe ( Int, Int ) -> Maybe Distribution.Scale -> LapHistory -> Entry -> Html msg
carSummary lapRange distScale lapHistory item =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-rows" "1fr auto auto"
            , property "row-gap" "12px"
            , property "align-content" "start"
            ]
        ]
        [ header item
        , summaryStats item
        , lapTimePanel lapRange distScale lapHistory item
        ]


{-| Panel that gathers "sector progress + Current/Last lap + lap-time distribution"
into one, concentrating all lap-time display here. The distribution draws one car
as a KDE curve, with both axes (lap time / density) aligned to the shared
`distScale` so the three columns share one scale (height = peak sharpness = pace
stability, comparable across cars).
-}
lapTimePanel : Maybe ( Int, Int ) -> Maybe Distribution.Scale -> LapHistory -> Entry -> Html msg
lapTimePanel maybeRange maybeScale lapHistory item =
    div
        [ css
            [ glassPanel
            , property "padding" "8px"
            , property "display" "grid"
            , property "row-gap" "8px"
            ]
        ]
        [ panelLabel "Lap time"
        , div [ css [ property "padding-bottom" "4px" ] ]
            [ SectorAndLaps.view item ]
        , div
            [ css
                [ property "padding-top" "4px"
                , property "border-top" "1px solid oklch(1 0 0 / 0.05)"
                ]
            ]
            [ case ( maybeRange, maybeScale ) of
                ( Just range, Just { domain, maxDensity } ) ->
                    LapTimeDistribution.view
                        { width = 300, height = 70, domain = domain, maxDensity = maxDensity }
                        [ Distribution.seriesOf lapHistory range item ]

                _ ->
                    text ""
            ]
        ]


header : Entry -> Html msg
header item =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "auto 1fr auto"
            , property "align-items" "start"
            , property "column-gap" "8px"
            ]
        ]
        [ CarNumberBadge.view item
        , div
            [ css
                [ property "display" "grid"
                , property "row-gap" "2px"
                ]
            ]
            [ div [ css [ property "font-size" "14px" ] ]
                [ text item.metadata.team ]
            , driverList item
            ]
        , statusBadge item.status
        ]


{-| As in the leaderboard, emphasizes the driver currently at the wheel and dims
the others.
-}
driverList : Entry -> Html msg
driverList item =
    let
        isCurrentDriver driver =
            item.currentDriver
                |> Maybe.map (Driver.isSame driver)
                |> Maybe.withDefault False
    in
    div
        [ css
            [ property "display" "flex"
            , property "flex-wrap" "wrap"
            , property "column-gap" "8px"
            , property "row-gap" "2px"
            , property "font-size" "11px"
            ]
        ]
        (List.map
            (\driver ->
                div
                    [ css
                        [ if isCurrentDriver driver then
                            opacity (num 1)

                          else
                            opacity (num 0.4)
                        ]
                    ]
                    [ text (Driver.toFullName driver) ]
            )
            item.metadata.drivers
        )


statusBadge : Status -> Html msg
statusBadge status =
    case status of
        InPit ->
            div
                [ css
                    [ property "display" "grid"
                    , property "place-items" "center"
                    , property "padding" "1px 6px"
                    , property "border-radius" "9999px"
                    , property "border" "1px solid hsl(0 0% 100% / 0.6)"
                    , property "font-size" "9px"
                    , property "font-weight" "700"
                    ]
                ]
                [ text "IN PIT" ]

        Retired ->
            div
                [ css
                    [ property "padding" "1px 6px"
                    , property "border-radius" "3px"
                    , property "background-color" "hsl(0 70% 45%)"
                    , property "font-size" "9px"
                    , property "font-weight" "700"
                    , property "letter-spacing" "0.05em"
                    ]
                ]
                [ text "RETIRED" ]

        _ ->
            text ""


summaryStats : Entry -> Html msg
summaryStats item =
    div
        [ css
            [ glassPanel
            , property "display" "grid"
            , property "grid-template-columns" "repeat(5, minmax(0, 1fr))"
            ]
        ]
        [ statCell "Pos" (text ("P" ++ String.fromInt item.position))
        , statCell "Class" (text ("P" ++ String.fromInt item.positionInClass))
        , statCell "Laps" (text (String.fromInt item.lapsCompleted))
        , statCell "Gap" (text (Gap.toString item.gapToLeader))
        , statCell "Int" (text (Gap.toString item.intervalToAhead))
        ]


{-| Small cell for packing position/gap values into a single strip. Cells are
separated by a left divider (the first cell has none).
-}
statCell : String -> Html msg -> Html msg
statCell label valueHtml =
    div
        [ css
            [ property "display" "grid"
            , property "row-gap" "1px"
            , property "justify-items" "center"
            , property "padding" "4px 2px"
            , property "border-left" "1px solid hsl(0 0% 100% / 0.05)"
            , Css.firstChild [ property "border-left" "none" ]
            ]
        ]
        [ div
            [ css
                [ property "font-size" "8px"
                , property "text-transform" "uppercase"
                , property "letter-spacing" "0.03em"
                , opacity (num 0.5)
                ]
            ]
            [ text label ]
        , div
            [ css
                [ property "font-size" "12px"
                , property "font-variant-numeric" "tabular-nums"
                ]
            ]
            [ valueHtml ]
        ]
