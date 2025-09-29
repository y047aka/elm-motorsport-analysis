module Motorsport.Widget.Compare exposing (Actions, Props, view)

import Css exposing (property, px, width)
import Data.Series as Series
import Data.Series.EventSummary exposing (EventSummary)
import Html.Styled as Html exposing (Html, div, img, text)
import Html.Styled.Attributes exposing (class, css, disabled, src)
import Html.Styled.Events exposing (onClick)
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Chart.Histogram as Histogram
import Motorsport.Clock as Clock
import Motorsport.Leaderboard as Leaderboard
import Motorsport.RaceControl.ViewModel exposing (ViewModel, ViewModelItem)
import Motorsport.Widget.Compare.LapTimeProgression as LapTimeProgression
import Motorsport.Widget.Compare.PositionProgression as PositionProgression



-- TYPES


type alias Props msg =
    { eventSummary : EventSummary
    , viewModel : ViewModel
    , clock : Clock.Model
    , analysis : Analysis
    , carA : Maybe ViewModelItem
    , carB : Maybe ViewModelItem
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
            , property "grid-template-columns" "1fr 1fr 1fr"
            , property "column-gap" "16px"
            ]
        ]
        [ div [ css [ property "grid-column" "1" ] ]
            [ detailColumn "Car A" props props.carA ]
        , div
            [ css
                [ property "grid-column" "2"
                , property "display" "grid"
                , property "grid-template-rows" "auto 1fr"
                , property "align-items" "start"
                , property "row-gap" "16px"
                ]
            ]
            [ controls props.actions props.carA props.carB
            , PositionProgression.view
                props.clock
                props.viewModel
                props.carA
                props.carB
            , LapTimeProgression.view
                props.clock
                props.viewModel
                props.carA
                props.carB
            ]
        , div [ css [ property "grid-column" "3" ] ]
            [ detailColumn "Car B" props props.carB ]
        ]


controls : Actions msg -> Maybe ViewModelItem -> Maybe ViewModelItem -> Html msg
controls actions carA carB =
    let
        canSwap =
            case ( carA, carB ) of
                ( Just _, Just _ ) ->
                    True

                _ ->
                    False
    in
    div
        [ css
            [ property "display" "grid"
            , property "grid-auto-flow" "column"
            , property "justify-content" "center"
            , property "align-items" "center"
            , property "column-gap" "10px"
            ]
        ]
        [ Html.button
            [ class "btn btn-xs"
            , onClick actions.swap
            , disabled (not canSwap)
            ]
            [ text "Swap" ]
        ]


detailColumn : String -> Props msg -> Maybe ViewModelItem -> Html msg
detailColumn label props maybeItem =
    case maybeItem of
        Just item ->
            detailBody
                { eventSummary = props.eventSummary
                , analysis = props.analysis
                , actions = props.actions
                }
                item

        Nothing ->
            emptyState label


type alias Props_ msg =
    { eventSummary : EventSummary
    , analysis : Analysis
    , actions : Actions msg
    }


detailBody : Props_ msg -> ViewModelItem -> Html msg
detailBody { eventSummary, analysis, actions } item =
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
        [ Html.button [ class "btn btn-xs", onClick actions.clearA ] [ text "Clear" ]
        , metadataBlock item eventSummary.season
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
                , Histogram.view analysis 1.05 item.history
                ]
            ]
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
