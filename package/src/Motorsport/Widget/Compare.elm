module Motorsport.Widget.Compare exposing (Model, Msg(..), Props, init, update, view)

import Css exposing (property)
import Data.Series as Series
import Data.Series.EventSummary exposing (EventSummary)
import Html.Styled as Html exposing (Html, div, img, text)
import Html.Styled.Attributes exposing (css, src)
import Html.Styled.Events exposing (onClick)
import List.Extra
import List.NonEmpty as NonEmpty
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Chart.BoxPlot as BoxPlot
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


view : Props -> Model -> Html Msg
view props model =
    let
        selectedCars =
            resolveCars model.selectedCars props.viewModel
                |> List.sortBy .position
    in
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-rows" "auto auto"
            , property "row-gap" "16px"
            ]
        ]
        [ chartsRow props selectedCars
        , carSelectorRow props model
        ]


chartsRow : Props -> List ViewModelItem -> Html Msg
chartsRow props selectedCars =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "1fr 1fr 1fr 1fr"
            , property "column-gap" "12px"
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


carSelectorRow : Props -> Model -> Html Msg
carSelectorRow props model =
    let
        groupedByClass =
            props.viewModel.items
                |> SortedList.toList
                |> List.Extra.gatherEqualsBy (.metadata >> .class)
                |> List.map (\( first, rest ) -> first :: rest)
    in
    div
        [ css
            [ property "display" "flex"
            , property "flex-direction" "column"
            , property "gap" "12px"
            , property "min-width" "0"
            , property "width" "100%"
            ]
        ]
        (groupedByClass
            |> List.map (viewClassGroup props.eventSummary.season model props)
        )


viewClassGroup : Int -> Model -> Props -> List ViewModelItem -> Html Msg
viewClassGroup season model props items =
    case items of
        [] ->
            text ""

        first :: _ ->
            div
                [ css
                    [ property "display" "flex"
                    , property "flex-direction" "column"
                    , property "gap" "8px"
                    ]
                ]
                [ div
                    [ css
                        [ property "display" "flex"
                        , property "gap" "8px"
                        , property "overflow-x" "auto"
                        , property "padding-bottom" "4px"
                        , property "min-width" "0"
                        ]
                    ]
                    (items |> List.map (carSelectorItem season model props))
                ]


carSelectorItem : Int -> Model -> Props -> ViewModelItem -> Html Msg
carSelectorItem season model props item =
    let
        isSelected =
            List.member item.metadata.carNumber model.selectedCars

        borderColor =
            if isSelected then
                "hsl(0 0% 80%)"

            else
                "hsl(0 0% 100% / 0.2)"

        backgroundColor =
            if isSelected then
                "hsl(0 0% 100% / 0.1)"

            else
                "transparent"

        isLeMans2025 =
            ( props.eventSummary.season, props.eventSummary.name ) == ( 2025, "24 Hours of Le Mans" )

        currentLapView =
            if isLeMans2025 then
                Leaderboard.viewCurrentLapColumn_LeMans24h

            else
                Leaderboard.viewCurrentLapColumn_Wec
    in
    div
        [ css
            [ property "display" "flex"
            , property "flex-direction" "column"
            , property "min-width" "110px"
            , property "width" "110px"
            , property "height" "140px"
            , property "padding" "8px"
            , property "border" ("2px solid " ++ borderColor)
            , property "border-radius" "8px"
            , property "background-color" backgroundColor
            , property "cursor" "pointer"
            , property "transition" "all 0.2s"
            ]
        , onClick (ToggleCar item.metadata.carNumber)
        ]
        [ -- Top row: Position and car number
          div
            [ css
                [ property "display" "flex"
                , property "justify-content" "space-between"
                , property "align-items" "center"
                , property "margin-bottom" "4px"
                ]
            ]
            [ div
                [ css
                    [ property "font-size" "11px"
                    , property "font-weight" "600"
                    , property "opacity" "0.7"
                    ]
                ]
                [ text ("P" ++ String.fromInt item.position) ]
            , Leaderboard.viewCarNumberColumn_Wec season item.metadata
            ]
        , carImage season item.metadata.carNumber
        , viewCurrentDriver item
        , currentLapView props.analysis item
        ]


carImage : Int -> String -> Html msg
carImage season carNumber =
    div
        [ css
            [ property "flex" "1"
            , property "display" "flex"
            , property "align-items" "center"
            , property "justify-content" "center"
            ]
        ]
        [ case Series.carImageUrl_Wec season carNumber of
            Just url ->
                img
                    [ src url
                    , css
                        [ property "width" "100%"
                        , property "object-fit" "contain"
                        ]
                    ]
                    []

            Nothing ->
                div
                    [ css
                        [ property "width" "100%"
                        , property "display" "flex"
                        , property "align-items" "center"
                        , property "justify-content" "center"
                        , property "background-color" "hsl(0 0% 100% / 0.05)"
                        , property "font-size" "24px"
                        , property "font-weight" "700"
                        , property "opacity" "0.3"
                        ]
                    ]
                    [ text carNumber ]
        ]


viewCurrentDriver : ViewModelItem -> Html msg
viewCurrentDriver item =
    div
        [ css
            [ property "text-align" "center"
            , property "font-size" "10px"
            , property "opacity" "0.7"
            , property "margin-bottom" "4px"
            , property "white-space" "nowrap"
            , property "overflow" "hidden"
            , property "text-overflow" "ellipsis"
            ]
        ]
        [ item.currentDriver
            |> Maybe.map (\driver -> text driver.name)
            |> Maybe.withDefault (text "-")
        ]
