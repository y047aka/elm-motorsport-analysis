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
import Motorsport.Clock as Clock
import Motorsport.Leaderboard as Leaderboard
import Motorsport.RaceControl.ViewModel exposing (ViewModel, ViewModelItem)
import Motorsport.Widget.CloseBattles as CloseBattles
import Motorsport.Widget.Compare.LapTimeProgression as LapTimeProgression
import Motorsport.Widget.Compare.PositionProgression as PositionProgression
import SortedList



-- TYPES


type alias Model =
    { carA : Maybe String
    , carB : Maybe String
    }


init : Model
init =
    { carA = Nothing
    , carB = Nothing
    }


type Msg
    = SelectCar String
    | ClearCarA
    | ClearCarB


update : Msg -> Model -> Model
update msg model =
    case msg of
        SelectCar carNumber ->
            case ( model.carA, model.carB ) of
                ( Nothing, Nothing ) ->
                    { model | carA = Just carNumber }

                ( Nothing, Just b ) ->
                    if b /= carNumber then
                        { model | carA = Just carNumber }

                    else
                        { carA = Just carNumber, carB = Nothing }

                ( Just a, Nothing ) ->
                    if a /= carNumber then
                        { model | carB = Just carNumber }

                    else
                        model

                ( Just a, Just b ) ->
                    if carNumber == a || carNumber == b then
                        model

                    else
                        { model | carB = Just carNumber }

        ClearCarA ->
            { model | carA = Nothing }

        ClearCarB ->
            { model | carB = Nothing }



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
        ( carA, carB ) =
            ( resolveCar model.carA props.viewModel
            , resolveCar model.carB props.viewModel
            )
    in
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-rows" "auto auto"
            , property "row-gap" "16px"
            ]
        ]
        [ carInfoRow props carA carB
        , chartsRow props carA carB
        ]


carInfoRow : Props -> Maybe ViewModelItem -> Maybe ViewModelItem -> Html Msg
carInfoRow props carA carB =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "1fr 1fr"
            , property "column-gap" "16px"
            ]
        ]
        [ detailColumn "Car A" ClearCarA props carA
        , detailColumn "Car B" ClearCarB props carB
        ]


chartsRow : Props -> Maybe ViewModelItem -> Maybe ViewModelItem -> Html Msg
chartsRow props carA carB =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "1fr 1fr 1fr"
            , property "column-gap" "12px"
            ]
        ]
        [ PositionProgression.view
            props.clock
            props.viewModel
            carA
            carB
        , LapTimeProgression.view
            props.clock
            props.viewModel
            carA
            carB
        , case ( carA, carB ) of
            ( Just itemA, Just itemB ) ->
                [ itemA, itemB ]
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

            _ ->
                text ""
        ]


detailColumn : String -> Msg -> Props -> Maybe ViewModelItem -> Html Msg
detailColumn label clearMsg props maybeItem =
    case maybeItem of
        Just item ->
            detailBody
                { eventSummary = props.eventSummary
                , analysis = props.analysis
                , onClear = clearMsg
                }
                item

        Nothing ->
            emptyState label


type alias DetailProps =
    { eventSummary : EventSummary
    , analysis : Analysis
    , onClear : Msg
    }


detailBody : DetailProps -> ViewModelItem -> Html Msg
detailBody { eventSummary, analysis, onClear } item =
    let
        isLeMans2025 =
            ( eventSummary.season, eventSummary.name ) == ( 2025, "24 Hours of Le Mans" )

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
            , property "row-gap" "20px"
            ]
        ]
        [ metadataBlock item eventSummary.season
        , div
            [ css
                [ property "display" "grid"
                , property "grid-template-columns" "1fr 1fr"
                , property "column-gap" "12px"
                , property "row-gap" "12px"
                ]
            ]
            [ div []
                [ Html.div [ class "text-xs opacity-60" ] [ text "Current Lap" ]
                , currentLapView analysis item
                ]
            , div []
                [ Html.div [ class "text-xs opacity-60" ] [ text "Last Lap" ]
                , lastLapView analysis item.lastLap
                ]
            , div [ css [ property "grid-column" "1 / -1" ] ]
                [ Html.div [ class "text-xs opacity-60" ] [ text "Histogram" ]
                , BoxPlot.view analysis 1.07 item.history
                ]
            ]
        , Html.button [ class "btn btn-xs", onClick onClear ] [ text "Clear" ]
        ]


metadataBlock : ViewModelItem -> Int -> Html msg
metadataBlock item season =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "auto auto 1fr"
            , property "column-gap" "15px"
            , property "justify-content" "center"
            , property "align-items" "center"
            ]
        ]
        [ Leaderboard.viewCarNumberColumn_Wec season item.metadata
        , carImage season item.metadata.carNumber
        , Leaderboard.viewDriverAndTeamColumn_Wec item
        ]


carImage : Int -> String -> Html msg
carImage season carNumber =
    case Series.carImageUrl_Wec season carNumber of
        Just url ->
            img [ src url, css [ width (px 80) ] ] []

        Nothing ->
            text ""


emptyState : String -> Html msg
emptyState label =
    div
        [ css
            [ property "display" "flex"
            , property "flex-direction" "column"
            , property "align-items" "center"
            , property "justify-content" "center"
            , property "row-gap" "8px"
            , property "padding" "12px"
            , property "border" "1px dashed hsl(0 0% 100% / 0.2)"
            , property "border-radius" "8px"
            , property "min-height" "140px"
            ]
        ]
        [ Html.div [ class "text-sm opacity-60" ] [ text label ]
        , Html.div [ class "text-xs opacity-40" ] [ text "Select a car to compare" ]
        ]


resolveCar : Maybe String -> ViewModel -> Maybe ViewModelItem
resolveCar maybeCarNumber viewModel =
    maybeCarNumber
        |> Maybe.andThen
            (\carNumber ->
                viewModel.items
                    |> SortedList.toList
                    |> List.Extra.find (\item -> item.metadata.carNumber == carNumber)
            )
