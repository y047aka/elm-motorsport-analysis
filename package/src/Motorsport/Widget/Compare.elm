module Motorsport.Widget.Compare exposing (Model, Msg(..), Props, init, update, view)

import Css exposing (property, px, width)
import Data.Series as Series
import Data.Series.EventSummary exposing (EventSummary)
import Html.Styled as Html exposing (Html, div, img, text)
import Html.Styled.Attributes exposing (class, css, src)
import Html.Styled.Events exposing (onClick)
import List.Extra
import List.NonEmpty as NonEmpty
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Chart.BoxPlot as BoxPlot
import Motorsport.Class
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
    | RemoveCar String


update : Msg -> Model -> Model
update msg model =
    case msg of
        ToggleCar carNumber ->
            if List.member carNumber model.selectedCars then
                { selectedCars = List.filter ((/=) carNumber) model.selectedCars }

            else
                { selectedCars = model.selectedCars ++ [ carNumber ] }

        RemoveCar carNumber ->
            { selectedCars = List.filter ((/=) carNumber) model.selectedCars }



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
            , property "grid-template-rows" "auto auto auto"
            , property "row-gap" "16px"
            ]
        ]
        [ carInfoRow props selectedCars
        , chartsRow props selectedCars
        , carSelectorRow props model
        ]


carInfoRow : Props -> List ViewModelItem -> Html Msg
carInfoRow props selectedCars =
    if List.isEmpty selectedCars then
        div
            [ css
                [ property "display" "flex"
                , property "justify-content" "center"
                , property "padding" "40px"
                ]
            ]
            [ Html.div [ class "text-sm opacity-40" ]
                [ text "Select cars from below to compare" ]
            ]

    else
        comparisonTable props selectedCars


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


comparisonTable : Props -> List ViewModelItem -> Html Msg
comparisonTable props selectedCars =
    let
        isLeMans2025 =
            ( props.eventSummary.season, props.eventSummary.name ) == ( 2025, "24 Hours of Le Mans" )
    in
    div
        [ css
            [ property "border" "1px solid hsl(0 0% 100% / 0.1)"
            , property "border-radius" "8px"
            , property "overflow" "hidden"
            ]
        ]
        [ tableHeader
        , div [] (selectedCars |> List.map (tableRow props.eventSummary.season props.analysis isLeMans2025))
        ]


tableHeader : Html Msg
tableHeader =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "50px 60px 100px 1fr 120px 120px 60px"
            , property "gap" "8px"
            , property "padding" "8px 12px"
            , property "background-color" "hsl(0 0% 100% / 0.05)"
            , property "border-bottom" "1px solid hsl(0 0% 100% / 0.1)"
            ]
        ]
        [ Html.div [ class "text-xs opacity-60 text-center" ] [ text "Pos" ]
        , Html.div [ class "text-xs opacity-60 text-center" ] [ text "Car" ]
        , Html.div [] []
        , Html.div [ class "text-xs opacity-60" ] [ text "Driver / Team" ]
        , Html.div [ class "text-xs opacity-60 text-center" ] [ text "Current Lap" ]
        , Html.div [ class "text-xs opacity-60 text-center" ] [ text "Last Lap" ]
        , Html.div [] []
        ]


tableRow : Int -> Analysis -> Bool -> ViewModelItem -> Html Msg
tableRow season analysis isLeMans2025 item =
    let
        ( currentLapView, lastLapView ) =
            if isLeMans2025 then
                ( Leaderboard.viewCurrentLapColumn_LeMans24h
                , Leaderboard.viewLastLapColumn_LeMans24h
                )

            else
                ( Leaderboard.viewCurrentLapColumn_Wec
                , Leaderboard.viewLastLapColumn_Wec
                )
    in
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "50px 60px 100px 1fr 120px 120px 60px"
            , property "gap" "8px"
            , property "padding" "8px 12px"
            , property "align-items" "center"
            , property "border-bottom" "1px solid hsl(0 0% 100% / 0.08)"
            ]
        ]
        [ Html.div [ class "text-sm text-center" ] [ text (String.fromInt item.position) ]
        , Leaderboard.viewCarNumberColumn_Wec season item.metadata
        , carImage season item.metadata.carNumber
        , Leaderboard.viewDriverAndTeamColumn_Wec item
        , currentLapView analysis item
        , lastLapView analysis item.lastLap
        , Html.button
            [ class "btn btn-xs"
            , onClick (RemoveCar item.metadata.carNumber)
            ]
            [ text "Clear" ]
        ]


carImage : Int -> String -> Html msg
carImage season carNumber =
    case Series.carImageUrl_Wec season carNumber of
        Just url ->
            img [ src url, css [ width (px 80) ] ] []

        Nothing ->
            text ""


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
    div
        [ css
            [ property "display" "flex"
            , property "gap" "8px"
            , property "overflow-x" "auto"
            , property "padding" "8px 0"
            ]
        ]
        (props.viewModel.items
            |> SortedList.toList
            |> List.map (carSelectorItem props.eventSummary.season model)
        )


carSelectorItem : Int -> Model -> ViewModelItem -> Html Msg
carSelectorItem season model item =
    let
        isSelected =
            List.member item.metadata.carNumber model.selectedCars

        borderColor =
            if isSelected then
                "hsl(200 100% 50%)"

            else
                "hsl(0 0% 100% / 0.2)"

        backgroundColor =
            if isSelected then
                "hsl(0 0% 100% / 0.1)"

            else
                "transparent"

        classColor =
            Motorsport.Class.toHexColor season item.metadata.class
    in
    div
        [ css
            [ property "display" "flex"
            , property "flex-direction" "column"
            , property "align-items" "center"
            , property "justify-content" "center"
            , property "min-width" "60px"
            , property "height" "70px"
            , property "padding" "8px"
            , property "border" ("2px solid " ++ borderColor)
            , property "border-radius" "6px"
            , property "background-color" backgroundColor
            , property "cursor" "pointer"
            , property "transition" "all 0.2s"
            ]
        , onClick (ToggleCar item.metadata.carNumber)
        ]
        [ div
            [ css
                [ property "width" "24px"
                , property "height" "4px"
                , Css.backgroundColor classColor
                , property "border-radius" "2px"
                , property "margin-bottom" "6px"
                ]
            ]
            []
        , div
            [ css
                [ property "font-size" "18px"
                , property "font-weight" "700"
                ]
            ]
            [ text item.metadata.carNumber ]
        ]
