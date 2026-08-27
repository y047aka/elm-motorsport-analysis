module View.RaceEvents exposing (view)

{-| Race events table.

Renders timeline events that have already occurred (up to the current clock
elapsed time) as a sortable table.

@docs view

-}

import Compare
import DataView
import Html exposing (Html, div, text)
import Motorsport.Clock as Clock
import Motorsport.Instant as Instant
import Motorsport.Race.TimelineEvent exposing (CarEventType(..), EventType(..), TimelineEvent)
import Motorsport.Replay as Replay


view : (DataView.Msg -> msg) -> DataView.Model -> Replay.Model -> Html msg
view toMsg eventsState replay =
    let
        currentElapsed =
            Clock.getElapsed replay.playback

        -- The race builds its timeline in time order, and filtering keeps it.
        occurredEvents =
            replay.race.timelineEvents
                |> List.filter (\event -> Instant.compare event.eventTime currentElapsed /= GT)
    in
    div []
        [ Html.h2 [] [ text "Race Events" ]
        , DataView.view (config toMsg) eventsState occurredEvents
        ]


config : (DataView.Msg -> msg) -> DataView.Config TimelineEvent msg
config toMsg =
    { toId = .eventTime >> Instant.toString
    , toMsg = toMsg
    , columns =
        [ DataView.customColumn
            { label = "Time"
            , getter = .eventTime >> Instant.toString
            , sorter = Compare.by (.eventTime >> Instant.toDuration)
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

        CarEvent _ TookLead ->
            "Took the Lead"

        CarEvent _ (PitIn _) ->
            "Pit In"

        CarEvent _ (PitOut _) ->
            "Pit Out"

        CarEvent _ Retirement ->
            "Retirement"

        CarEvent _ Checkered ->
            "Checkered Flag"
