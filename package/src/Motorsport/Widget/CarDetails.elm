module Motorsport.Widget.CarDetails exposing (Props, view)

import Css exposing (property, px, width)
import Data.Series as Series
import Data.Series.EventSummary exposing (EventSummary)
import Html.Styled as Html exposing (Html, div, img, text)
import Html.Styled.Attributes exposing (class, css, src)
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Clock as Clock
import Motorsport.Leaderboard as Leaderboard
import Motorsport.RaceControl.ViewModel exposing (ViewModel, ViewModelItem)
import Motorsport.Widget as Widget
import Motorsport.Widget.CarDetails.LapTimeProgression as LapTimeProgression
import Motorsport.Widget.CarDetails.PositionProgression as PositionProgression


type alias Props =
    { eventSummary : EventSummary
    , viewModel : ViewModel
    , clock : Clock.Model
    , selectedCar : Maybe ViewModelItem
    , analysis : Analysis
    }


view : Props -> Html msg
view props =
    let
        ( title, body ) =
            case props.selectedCar of
                Nothing ->
                    ( "Car Details"
                    , Widget.emptyState "Select a car from the standings to view details"
                    )

                Just item ->
                    ( item.metadata.carNumber ++ " - " ++ item.metadata.team
                    , div
                        [ css
                            [ property "display" "grid"
                            , property "row-gap" "16px"
                            ]
                        ]
                        [ detailHeader props.eventSummary.season item
                        , detailBody props item
                        ]
                    )
    in
    Widget.container title body


detailHeader : Int -> ViewModelItem -> Html msg
detailHeader season item =
    let
        carImage carNumber =
            case Series.carImageUrl_Wec season carNumber of
                Just url ->
                    img [ src url, css [ width (px 100) ] ] []

                Nothing ->
                    text ""
    in
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "auto auto 1fr"
            , property "align-items" "center"
            , property "column-gap" "10px"
            , property "padding-bottom" "12px"
            , property "border-bottom" "1px solid hsl(0 0% 100% / 0.1)"
            ]
        ]
        [ Leaderboard.viewCarNumberColumn_Wec season item.metadata
        , Leaderboard.viewDriverAndTeamColumn_Wec item
        , carImage item.metadata.carNumber
        ]


detailBody : Props -> ViewModelItem -> Html msg
detailBody { eventSummary, viewModel, clock, analysis } item =
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
                ]
            ]
            [ div []
                [ Html.div [ class "text-xs opacity-60" ] [ text "Current Lap" ]
                , (case ( eventSummary.season, eventSummary.name ) of
                    ( 2025, "24 Hours of Le Mans" ) ->
                        Leaderboard.viewCurrentLapColumn_LeMans24h

                    _ ->
                        Leaderboard.viewCurrentLapColumn_Wec
                  )
                    analysis
                    item
                ]
            , div []
                [ Html.div [ class "text-xs opacity-60" ] [ text "Last Lap" ]
                , (case ( eventSummary.season, eventSummary.name ) of
                    ( 2025, "24 Hours of Le Mans" ) ->
                        Leaderboard.viewLastLapColumn_LeMans24h

                    _ ->
                        Leaderboard.viewLastLapColumn_Wec
                  )
                    analysis
                    item.lastLap
                ]
            ]
        , PositionProgression.view clock viewModel item.metadata
        , LapTimeProgression.view clock viewModel item.metadata
        ]
