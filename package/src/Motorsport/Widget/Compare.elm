module Motorsport.Widget.Compare exposing (Chart(..), viewComparison)

{-| Widget showing per-car detail (summary + in-class position history), drawn
as plain inline content; the caller chooses which cars to compare.

`viewComparison` embeds a same-class selector to switch between them. Summaries
sit side by side; the two lower charts are tabbed so only one shows at a time.

@docs Chart, viewComparison

-}

import Html exposing (Html, div, text)
import Html.Attributes as Attributes
import Motorsport.Chart.GapChart as GapChart
import Motorsport.Race.LapHistory exposing (LapHistory)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Widget.Compare.CarSelector as CarSelector
import Motorsport.Widget.Compare.CarSummary as CarSummary
import Motorsport.Widget.Compare.ChartTabs as ChartTabs
import Motorsport.Widget.Compare.PositionProgression as PositionProgression


{-| Tab for the lower chart. Only one is shown at a time.
-}
type Chart
    = GapChart
    | PositionChart


{-| Compare the cars in `selectedCarNumbers`. The first sets the class reference
for both charts and for the embedded selector, whose chips fire `onToggleCar`;
the widget holds no selection of its own. `focused` is the one car that
selection is, the others being rivals derived from it, and is what the selector
marks. Only `activeChart` is rendered; clicking a tab fires `onSelectChart`.
-}
viewComparison :
    { onToggleCar : String -> msg
    , activeChart : Chart
    , onSelectChart : Chart -> msg
    , focused : String
    }
    -> Snapshot
    -> List String
    -> Html msg
viewComparison { onToggleCar, activeChart, onSelectChart, focused } snapshot selectedCarNumbers =
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
            in
            div
                [ Attributes.class "grid gap-y-3" ]
                [ div
                    [ Attributes.class "flex items-center gap-x-3" ]
                    [ CarSelector.classBadge first.metadata.class
                    , CarSelector.carSelector onToggleCar snapshot class (Just focused)
                    ]
                , div
                    [ Attributes.class "grid grid-flow-col auto-cols-[minmax(0,1fr)] gap-x-4" ]
                    (List.map CarSummary.carSummary selectedEntries)
                , ChartTabs.chartTabs onSelectChart
                    activeChart
                    [ ( GapChart
                      , "Gap to group avg"
                      , \() -> gapChart lapRange lapHistory selectedEntries
                      )
                    , ( PositionChart
                      , "Position progression"
                      , \() ->
                            PositionProgression.view
                                { width = 1000, height = 250 }
                                snapshot
                                { class = class
                                , highlighted = selectedCarNumbers
                                }
                      )
                    ]
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
