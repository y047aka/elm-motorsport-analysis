module View.RaceEvents exposing (view)

{-| Race events table.

Renders timeline events that have already occurred (up to the current clock
elapsed time) as a sortable table.

@docs view

-}

import DataView
import Html.Styled as Html exposing (Html, div, text)
import Motorsport.Clock as Clock
import Motorsport.Duration as Duration
import Motorsport.RaceControl as RaceControl
import Motorsport.TimelineEvent exposing (CarEventType(..), EventType(..), TimelineEvent)
import Motorsport.Utils exposing (compareBy)


view : (DataView.Msg -> msg) -> DataView.Model -> RaceControl.Model -> Html msg
view toMsg eventsState raceControl =
    let
        currentElapsed =
            Clock.getElapsed raceControl.playback

        occurredEvents =
            raceControl.race.timelineEvents
                |> List.filter (\event -> currentElapsed >= event.eventTime)
                |> List.sortBy .eventTime
    in
    div []
        [ Html.h2 [] [ text "Race Events" ]
        , DataView.view (config toMsg) eventsState occurredEvents
        ]


config : (DataView.Msg -> msg) -> DataView.Config TimelineEvent msg
config toMsg =
    { toId = .eventTime >> Duration.toString
    , toMsg = toMsg
    , columns =
        [ DataView.customColumn
            { label = "Time"
            , getter = .eventTime >> Duration.toString
            , sorter = compareBy .eventTime
            }
        , DataView.stringColumn
            { label = "Car"
            , getter =
                \event ->
                    case event.eventType of
                        CarEvent carNumber _ ->
                            carNumber

                        _ ->
                            ""
            }
        , DataView.stringColumn
            { label = "Event"
            , getter = .eventType >> eventTypeToString
            }
        ]
    }


eventTypeToString : EventType -> String
eventTypeToString eventType =
    case eventType of
        RaceStart ->
            "Race Started"

        CarEvent _ (Start _) ->
            "Start"

        CarEvent _ (LapCompleted lap _) ->
            "Lap " ++ String.fromInt lap ++ " Completed"

        CarEvent _ (PitIn _) ->
            "Pit In"

        CarEvent _ (PitOut _) ->
            "Pit Out"

        CarEvent _ Retirement ->
            "Retirement"

        CarEvent _ Checkered ->
            "Checkered Flag"
