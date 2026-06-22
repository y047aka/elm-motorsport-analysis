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
import List.Extra
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Chart.GapChart as GapChart
import Motorsport.Clock as Clock
import Motorsport.Standings as Standings exposing (Standings, StandingsEntry)
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
    { season : Int
    , analysis : Analysis
    , clock : Clock.Model
    , onToggleCar : String -> msg
    , activeChart : Chart
    , onSelectChart : Chart -> msg
    }
    -> Standings
    -> List String
    -> Html msg
viewComparison { season, analysis, clock, onToggleCar, activeChart, onSelectChart } standings selectedCarNumbers =
    let
        entriesByNumber =
            Standings.toList standings

        selectedEntries =
            selectedCarNumbers
                |> List.filterMap
                    (\carNumber ->
                        List.Extra.find (\e -> e.metadata.carNumber == carNumber) entriesByNumber
                    )
    in
    case selectedEntries of
        [] ->
            text ""

        first :: _ ->
            let
                class =
                    first.metadata.class

                lapRange =
                    PositionProgression.lapRange clock standings class

                distSeries =
                    case lapRange of
                        Just range ->
                            List.map (Distribution.seriesOf standings range) selectedEntries

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
                    [ CarSelector.classBadge season class
                    , CarSelector.carSelector onToggleCar standings class selectedCarNumbers
                    ]
                , div
                    [ css
                        [ property "display" "grid"
                        , property "grid-template-columns" ("repeat(" ++ String.fromInt maxComparisonCars ++ ", minmax(0, 1fr))")
                        , property "column-gap" "16px"
                        ]
                    ]
                    (List.map (CarSummary.carSummary analysis lapRange distScale standings) selectedEntries
                        ++ List.repeat (maxComparisonCars - List.length selectedEntries) CarSummary.placeholderCard
                    )
                , ChartTabs.chartTabs onSelectChart
                    activeChart
                    [ ( GapChart
                      , "Gap to group avg"
                      , \() -> gapChart lapRange standings selectedEntries
                      )
                    , ( PositionChart
                      , "Position progression"
                      , \() ->
                            PositionProgression.view
                                { width = 1000, height = 250 }
                                clock
                                standings
                                { class = class
                                , highlighted = selectedCarNumbers
                                }
                      )
                    ]
                ]


{-| Chart combining the relative gaps measured against the selected cars' group average.
-}
gapChart : Maybe ( Int, Int ) -> Standings -> List StandingsEntry -> Html msg
gapChart maybeRange standings entries =
    case maybeRange of
        Just range ->
            GapChart.gapChartView range standings entries

        Nothing ->
            text ""
