module Motorsport.Widget.Compare exposing (Model, Msg(..), Props, init, resolveCars, update, viewCharts)

import Css exposing (property)
import Data.Series.EventSummary exposing (EventSummary)
import Html.Styled exposing (Html, button, div, text)
import Html.Styled.Attributes exposing (class, css)
import Html.Styled.Events exposing (onClick)
import List.Extra
import List.NonEmpty as NonEmpty
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Chart.BoxPlot as BoxPlot
import Motorsport.Chart.Tracker as TrackerChart
import Motorsport.Clock as Clock
import Motorsport.Standings as Standings exposing (Standings, StandingsEntry)
import Motorsport.Widget.CloseBattles as CloseBattles
import Motorsport.Widget.Compare.PositionProgression as PositionProgression



-- TYPES


type ActiveChart
    = TrackerChart
    | PositionProgressionChart
    | CloseBattlesChart
    | BoxPlotChart


type alias Model =
    { selectedCars : List String
    , activeChart : ActiveChart
    }


init : Model
init =
    { selectedCars = []
    , activeChart = TrackerChart
    }


type Msg
    = ToggleCar String
    | SwitchChart ActiveChart


update : Msg -> Model -> Model
update msg model =
    case msg of
        ToggleCar carNumber ->
            if List.member carNumber model.selectedCars then
                { model | selectedCars = List.filter ((/=) carNumber) model.selectedCars }

            else
                { model | selectedCars = model.selectedCars ++ [ carNumber ] }

        SwitchChart chart ->
            { model | activeChart = chart }



-- Props


type alias Props =
    { eventSummary : EventSummary
    , standings : Standings
    , clock : Clock.Model
    , analysis : Analysis
    }



-- VIEW


viewCharts : { width : Float, height : Float } -> Props -> Model -> Html Msg
viewCharts size props model =
    div
        [ css
            [ property "height" "100%"
            , property "display" "grid"
            , property "grid-template-rows" "auto 1fr"
            , property "gap" "8px"
            , property "place-items" "center"
            ]
        ]
        [ viewChartTabs model.activeChart
        , viewActiveChart model.activeChart size props model
        ]


viewChartTabs : ActiveChart -> Html Msg
viewChartTabs activeChart =
    div
        [ class "join"
        , css [ property "justify-self" "left" ]
        ]
        [ chartTabButton "Tracker" TrackerChart (activeChart == TrackerChart)
        , chartTabButton "Position" PositionProgressionChart (activeChart == PositionProgressionChart)
        , chartTabButton "Battles" CloseBattlesChart (activeChart == CloseBattlesChart)
        , chartTabButton "Box Plot" BoxPlotChart (activeChart == BoxPlotChart)
        ]


chartTabButton : String -> ActiveChart -> Bool -> Html Msg
chartTabButton label chart isActive =
    button
        [ onClick (SwitchChart chart)
        , class
            ("join-item btn btn-sm btn-soft"
                ++ (if isActive then
                        " btn-active"

                    else
                        ""
                   )
            )
        ]
        [ text label ]


viewActiveChart : ActiveChart -> { width : Float, height : Float } -> Props -> Model -> Html Msg
viewActiveChart activeChart size props model =
    let
        selectedCars =
            resolveCars model.selectedCars props.standings
                |> List.sortBy .position
    in
    case activeChart of
        TrackerChart ->
            TrackerChart.view
                { season = props.eventSummary.season, eventName = props.eventSummary.name }
                props.analysis
                props.standings

        PositionProgressionChart ->
            PositionProgression.view
                size
                props.clock
                props.standings
                selectedCars

        CloseBattlesChart ->
            selectedCars
                |> List.sortBy .position
                |> NonEmpty.fromList
                |> Maybe.map
                    (\cars ->
                        let
                            leader =
                                NonEmpty.head cars
                        in
                        CloseBattles.closeBattleItem
                            size
                            props.standings
                            { cars = cars
                            , position = leader.position
                            }
                    )
                |> Maybe.withDefault (text "")

        BoxPlotChart ->
            BoxPlot.view size props.analysis props.standings selectedCars


resolveCars : List String -> Standings -> List StandingsEntry
resolveCars carNumbers standings =
    carNumbers
        |> List.filterMap
            (\carNumber ->
                Standings.toList standings
                    |> List.Extra.find (\item -> item.metadata.carNumber == carNumber)
            )
