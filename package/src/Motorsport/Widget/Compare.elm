module Motorsport.Widget.Compare exposing (Model, Msg(..), Props, init, update, viewCarSelector, viewCharts)

import Css exposing (backgroundColor, property)
import Data.Series as Series
import Data.Series.EventSummary exposing (EventSummary)
import Html.Styled as Html exposing (Html, div, img, text)
import Html.Styled.Attributes exposing (class, css, src)
import Html.Styled.Events exposing (onClick)
import List.Extra
import List.NonEmpty as NonEmpty
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Chart.BoxPlot as BoxPlot
import Motorsport.Class as Class
import Motorsport.Clock as Clock
import Motorsport.Leaderboard as Leaderboard
import Motorsport.RaceControl.ViewModel exposing (ViewModel, ViewModelItem)
import Motorsport.Widget.CloseBattles as CloseBattles
import Motorsport.Widget.Compare.LapTimeProgression as LapTimeProgression
import Motorsport.Widget.Compare.PositionProgression as PositionProgression
import SortedList



-- TYPES


type alias Model =
    { selectedCars : List String }


init : Model
init =
    { selectedCars = [] }


type Msg
    = ToggleCar String


update : Msg -> Model -> Model
update msg model =
    case msg of
        ToggleCar carNumber ->
            if List.member carNumber model.selectedCars then
                { selectedCars = List.filter ((/=) carNumber) model.selectedCars }

            else
                { selectedCars = model.selectedCars ++ [ carNumber ] }



-- Props


type alias Props =
    { eventSummary : EventSummary
    , viewModel : ViewModel
    , clock : Clock.Model
    , analysis : Analysis
    }



-- VIEW


viewCharts : Props -> Model -> Html Msg
viewCharts props model =
    let
        selectedCars =
            resolveCars model.selectedCars props.viewModel
                |> List.sortBy .position
    in
    div
        [ css
            [ property "display" "flex"
            , property "flex-direction" "column"
            , property "gap" "12px"
            ]
        ]
        [ PositionProgression.view
            props.clock
            props.viewModel
            selectedCars
        , LapTimeProgression.view
            props.clock
            props.viewModel
            selectedCars
        , selectedCars
            |> List.sortBy .position
            |> NonEmpty.fromList
            |> Maybe.map
                (\cars ->
                    let
                        leader =
                            NonEmpty.head cars
                    in
                    CloseBattles.closeBattleItem
                        { cars = cars
                        , position = leader.position
                        }
                )
            |> Maybe.withDefault (text "")
        , BoxPlot.view props.analysis selectedCars
        ]


resolveCars : List String -> ViewModel -> List ViewModelItem
resolveCars carNumbers viewModel =
    carNumbers
        |> List.filterMap
            (\carNumber ->
                viewModel.items
                    |> SortedList.toList
                    |> List.Extra.find (\item -> item.metadata.carNumber == carNumber)
            )


viewCarSelector : Props -> Model -> Html Msg
viewCarSelector props model =
    div
        [ css
            [ property "display" "flex"
            , property "flex-wrap" "wrap"
            , property "gap" "8px"
            , property "min-width" "0"
            , property "width" "100%"
            ]
        ]
        (props.viewModel.items
            |> SortedList.toList
            |> List.map (carSelectorItem props.eventSummary.season model props)
        )


carSelectorItem : Int -> Model -> Props -> ViewModelItem -> Html Msg
carSelectorItem season model props item =
    let
        isSelected =
            List.member item.metadata.carNumber model.selectedCars

        borderColor =
            if isSelected then
                "hsl(0 0% 80%)"

            else
                "hsl(0 0% 100% / 0)"

        backgroundColorValue =
            if isSelected then
                "hsl(0 0% 100% / 0.1)"

            else
                "var(--widget-bg)"

        isLeMans2025 =
            ( props.eventSummary.season, props.eventSummary.name ) == ( 2025, "24 Hours of Le Mans" )

        currentLapView =
            if isLeMans2025 then
                Leaderboard.viewCurrentLapColumn_LeMans24h

            else
                Leaderboard.viewCurrentLapColumn_Wec
    in
    div
        [ class "card card-sm"
        , css
            [ property "min-width" "240px"
            , property "width" "240px"
            , property "border" ("2px solid " ++ borderColor)
            , property "background-color" backgroundColorValue
            , property "cursor" "pointer"
            , property "transition" "all 0.2s"
            ]
        , onClick (ToggleCar item.metadata.carNumber)
        ]
        [ div
            [ class "card-body"
            , css
                [ property "padding" "8px"
                , property "display" "grid"
                , property "grid-template-columns" "auto auto 1fr"
                , property "grid-template-rows" "auto auto"
                , property "align-items" "center"
                , property "column-gap" "10px"
                , property "row-gap" "4px"
                ]
            ]
            [ -- Row 1, Col 1: Position and class
              div
                [ css
                    [ property "display" "flex"
                    , property "flex-direction" "column"
                    , property "gap" "2px"
                    , property "grid-row" "1"
                    , property "grid-column" "1"
                    ]
                ]
                [ div
                    [ css
                        [ property "font-size" "12px"
                        , property "font-weight" "600"
                        , property "opacity" "0.7"
                        ]
                    ]
                    [ text ("P" ++ String.fromInt item.position) ]
                , div
                    [ css
                        [ property "font-size" "8px"
                        , property "font-weight" "500"
                        , property "opacity" "0.5"
                        , property "line-height" "1"
                        ]
                    ]
                    [ text (Class.toString item.metadata.class) ]
                ]
            , -- Row 1, Col 2: Car number
              div
                [ css
                    [ property "grid-row" "1"
                    , property "grid-column" "2"
                    ]
                ]
                [ Leaderboard.viewCarNumberColumn_Wec season item.metadata ]
            , -- Row 1, Col 3: Team and Driver name
              div
                [ css
                    [ property "grid-row" "1"
                    , property "grid-column" "3"
                    , property "display" "grid"
                    , property "gap" "2px"
                    ]
                ]
                [ div
                    [ css
                        [ property "font-size" "10px"
                        , property "max-width" "100%"
                        ]
                    ]
                    [ text item.metadata.team ]
                , div
                    [ css
                        [ property "font-size" "10px"
                        , property "opacity" "0.6"
                        ]
                    ]
                    [ item.currentDriver
                        |> Maybe.map (\driver -> text driver.name)
                        |> Maybe.withDefault (text "-")
                    ]
                ]
            , -- Row 2, Col 1-2: Car image
              div
                [ css
                    [ property "grid-row" "2"
                    , property "grid-column" "1 / 3"
                    , property "display" "grid"
                    , property "place-items" "center"
                    ]
                ]
                [ carImage season item.metadata.carNumber ]
            , -- Row 2, Col 3: Lap info
              div
                [ css
                    [ property "grid-row" "2"
                    , property "grid-column" "3"
                    ]
                ]
                [ currentLapView props.analysis item ]
            ]
        ]

carImage : Int -> String -> Html msg
carImage season carNumber =
    div
        [ css
            [ property "width" "60px"
            , property "height" "40px"
            , property "display" "grid"
            , property "place-items" "center"
            ]
        ]
        [ case Series.carImageUrl_Wec season carNumber of
            Just url ->
                img
                    [ src url
                    , css
                        [ property "width" "100%"
                        , property "height" "100%"
                        , property "object-fit" "contain"
                        ]
                    ]
                    []

            Nothing ->
                div
                    [ css
                        [ property "width" "100%"
                        , property "height" "100%"
                        , property "display" "flex"
                        , property "align-items" "center"
                        , property "justify-content" "center"
                        , property "background-color" "hsl(0 0% 100% / 0.05)"
                        , property "font-size" "20px"
                        , property "font-weight" "700"
                        , property "opacity" "0.3"
                        ]
                    ]
                    [ text carNumber ]
        ]
