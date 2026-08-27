module Motorsport.Widget.Compare exposing (Chart(..), viewComparison)

{-| Widget showing per-car detail (summary + in-class position history). Intended
as the body of a popover/dialog; it does not carry the popover attributes itself.

`viewComparison` embeds a same-class car selector in the modal and compares up to
three cars, toggle-selected. Summaries sit side by side; the two lower charts are
tabbed so only one shows at a time (to save space).

@docs Chart, viewComparison

-}

import Css exposing (property)
import Html.Styled exposing (Html, div, text)
import Html.Styled.Attributes exposing (css)
import Motorsport.Chart.GapChart as GapChart
import Motorsport.Race.LapHistory exposing (LapHistory)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Widget.Compare.CarSelector as CarSelector
import Motorsport.Widget.Compare.CarSummary as CarSummary
import Motorsport.Widget.Compare.ChartTabs as ChartTabs
import Motorsport.Widget.Compare.Distribution as Distribution
import Motorsport.Widget.Compare.PositionProgression as PositionProgression


{-| Maximum number of cars that can be compared. The summary slot count
(including placeholders) matches this.
-}
maxComparisonCars : Int
maxComparisonCars =
    3


{-| Tab for the lower chart. Only one is shown at a time.
-}
type Chart
    = GapChart
    | PositionChart


{-| View that compares up to three same-class cars, toggle-selected within the
modal. `selectedCarNumbers` are the selected car numbers (the first sets the
chart's class reference). Each selector chip fires `onToggleCar` (the caller
enforces the 3-car limit). Only `activeChart` is rendered; clicking a tab fires
`onSelectChart`.
-}
viewComparison :
    { onToggleCar : String -> msg
    , activeChart : Chart
    , onSelectChart : Chart -> msg
    }
    -> Snapshot
    -> List String
    -> Html msg
viewComparison { onToggleCar, activeChart, onSelectChart } snapshot selectedCarNumbers =
    let
        lapHistory =
            Snapshot.lapHistory snapshot

        entriesByNumber =
            Snapshot.toList snapshot

        selectedEntries =
            entriesByNumber
                |> List.filter (\e -> List.member e.metadata.carNumber selectedCarNumbers)
    in
    case selectedEntries of
        [] ->
            text ""

        first :: _ ->
            let
                class =
                    first.metadata.class

                lapRange =
                    PositionProgression.lapRange snapshot class

                distSeries =
                    case lapRange of
                        Just range ->
                            List.map (Distribution.seriesOf lapHistory range) selectedEntries

                        Nothing ->
                            []

                distScale =
                    Distribution.scaleOf distSeries
            in
            div
                [ css
                    [ property "display" "grid"
                    , property "row-gap" "12px"
                    ]
                ]
                [ div
                    [ css
                        [ property "display" "flex"
                        , property "align-items" "center"
                        , property "column-gap" "12px"
                        ]
                    ]
                    [ CarSelector.classBadge first.metadata.class
                    , CarSelector.carSelector onToggleCar snapshot class selectedCarNumbers
                    ]
                , div
                    [ css
                        [ property "display" "grid"
                        , property "grid-template-columns" ("repeat(" ++ String.fromInt maxComparisonCars ++ ", minmax(0, 1fr))")
                        , property "column-gap" "16px"
                        ]
                    ]
                    (List.map (CarSummary.carSummary lapRange distScale lapHistory) selectedEntries
                        ++ List.repeat (maxComparisonCars - List.length selectedEntries) CarSummary.placeholderCard
                    )
                , Html.Styled.fromUnstyled
                    (ChartTabs.chartTabs onSelectChart
                        activeChart
                        [ ( GapChart
                          , "Gap to group avg"
                          , \() -> Html.Styled.toUnstyled (gapChart lapRange lapHistory selectedEntries)
                          )
                        , ( PositionChart
                          , "Position progression"
                          , \() ->
                                Html.Styled.toUnstyled
                                    (PositionProgression.view
                                        { width = 1000, height = 250 }
                                        snapshot
                                        { class = class
                                        , highlighted = selectedCarNumbers
                                        }
                                    )
                          )
                        ]
                    )
                ]


{-| Chart combining the relative gaps measured against the selected cars' group average.
-}
gapChart : Maybe ( Int, Int ) -> LapHistory -> List CarAt -> Html msg
gapChart maybeRange lapHistory entries =
    case maybeRange of
        Just range ->
            GapChart.gapChartView range lapHistory entries

        Nothing ->
            text ""
