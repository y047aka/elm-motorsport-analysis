module Motorsport.Widget.Compare exposing (Actions, Props, view)

import Css exposing (property, px, width)
import Data.Series as Series
import Data.Series.EventSummary exposing (EventSummary)
import Html.Styled as Html exposing (Html, div, img, text)
import Html.Styled.Attributes exposing (class, css, src)
import Html.Styled.Events exposing (onClick)
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Chart.Histogram as Histogram
import Motorsport.Clock as Clock
import Motorsport.Leaderboard as Leaderboard
import Motorsport.RaceControl.ViewModel exposing (ViewModel, ViewModelItem)
import Motorsport.Widget.CarDetails.LapTimeProgression as LapTimeProgression
import Motorsport.Widget.CarDetails.PositionProgression as PositionProgression



-- TYPES


type alias Props msg =
    { eventSummary : EventSummary
    , viewModel : ViewModel
    , clock : Clock.Model
    , analysis : Analysis
    , carA : ViewModelItem
    , carB : ViewModelItem
    , actions : Actions msg
    }


type alias Actions msg =
    { swap : msg
    , clearA : msg
    , clearB : msg
    }



-- VIEW


view : Props msg -> Html msg
view props =
    div
        [ css
            [ property "display" "grid"
            , property "row-gap" "16px"
            ]
        ]
        [ header props
        , body props
        ]


header : Props msg -> Html msg
header props =
    let
        season =
            props.eventSummary.season

        carImage carNumber =
            case Series.carImageUrl_Wec season carNumber of
                Just url ->
                    img [ src url, css [ width (px 80) ] ] []

                Nothing ->
                    text ""

        metadataBlock item =
            div
                [ css
                    [ property "display" "flex"
                    , property "column-gap" "15px"
                    , property "justify-content" "center"
                    , property "align-items" "center"
                    ]
                ]
                [ Leaderboard.viewCarNumberColumn_Wec season item.metadata
                , carImage item.metadata.carNumber
                , Leaderboard.viewDriverAndTeamColumn_Wec item
                ]
    in
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "1fr 1fr 1fr"
            , property "align-items" "center"
            , property "column-gap" "16px"
            , property "padding-bottom" "12px"
            , property "border-bottom" "1px solid hsl(0 0% 100% / 0.1)"
            ]
        ]
        [ metadataBlock props.carA
        , controls props.actions
        , metadataBlock props.carB
        ]


controls : Actions msg -> Html msg
controls actions =
    div
        [ css
            [ property "display" "grid"
            , property "grid-auto-flow" "column"
            , property "justify-content" "center"
            , property "align-items" "center"
            , property "column-gap" "10px"
            ]
        ]
        [ Html.button [ class "btn btn-xs", onClick actions.clearA ] [ text "Clear A" ]
        , Html.button [ class "btn btn-xs", onClick actions.swap ] [ text "Swap" ]
        , Html.button [ class "btn btn-xs", onClick actions.clearB ] [ text "Clear B" ]
        ]


body : Props msg -> Html msg
body props =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "1fr 1fr 1fr"
            , property "column-gap" "12px"
            , property "row-gap" "16px"
            ]
        ]
        [ div [ css [ property "grid-column" "1" ] ]
            [ detailBody
                { eventSummary = props.eventSummary
                , viewModel = props.viewModel
                , clock = props.clock
                , selectedCar = Just props.carA
                , analysis = props.analysis
                }
                props.carA
            ]
        , div [ css [ property "grid-column" "3" ] ]
            [ detailBody
                { eventSummary = props.eventSummary
                , viewModel = props.viewModel
                , clock = props.clock
                , selectedCar = Just props.carB
                , analysis = props.analysis
                }
                props.carB
            ]
        ]


type alias Props_ =
    { eventSummary : EventSummary
    , viewModel : ViewModel
    , clock : Clock.Model
    , selectedCar : Maybe ViewModelItem
    , analysis : Analysis
    }


detailBody : Props_ -> ViewModelItem -> Html msg
detailBody { eventSummary, viewModel, clock, analysis } item =
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
        [ div
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
                , Histogram.view analysis 1.05 item.history
                ]
            ]
        , PositionProgression.view clock viewModel item.metadata
        , LapTimeProgression.view clock viewModel item.metadata
        ]
