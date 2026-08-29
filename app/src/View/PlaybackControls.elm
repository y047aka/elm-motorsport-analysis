module View.PlaybackControls exposing (view)

{-| Playback controls: play/pause, skip, progress bar and speed selector.

Driven purely by a `Replay.Model`. Play/pause are surfaced as dedicated
callbacks because the caller resolves them against `Time.now`; every other
interaction is forwarded as a `Replay.Msg`.

@docs view

-}

import Html exposing (Html, div, text)
import Html.Attributes as Attributes
import Motorsport.Clock as Clock exposing (State(..))
import Motorsport.Duration as Duration
import Motorsport.Race as Race
import Motorsport.Replay as Replay
import String exposing (dropRight)
import UI.Button as Button
import UI.ButtonGroup as ButtonGroup
import UI.Slider as Slider
import UI.ToggleGroup as ToggleGroup


view :
    { replay : Replay.Model
    , onStart : msg
    , onPause : msg
    , toReplayMsg : Replay.Msg -> msg
    }
    -> Html msg
view config =
    div [ Attributes.class "flex items-center gap-8" ]
        [ div [ Attributes.class "flex items-center gap-2" ]
            [ viewPlayPauseButton config
            , viewSkipControls config.toReplayMsg config.replay.playback.state
            ]
        , viewProgressBar config.toReplayMsg config.replay
        , viewSpeedControls config.toReplayMsg config.replay.playback.playbackSpeed
        ]


viewPlayPauseButton :
    { a | replay : Replay.Model, onStart : msg, onPause : msg }
    -> Html msg
viewPlayPauseButton { replay, onStart, onPause } =
    let
        ( icon, action, isDisabled ) =
            case replay.playback.state of
                Initial ->
                    ( "▶", onStart, False )

                Started _ _ ->
                    ( "■", onPause, False )

                Paused _ ->
                    ( "▶", onStart, False )

                Finished ->
                    ( "▶", onStart, True )
    in
    Button.view
        { label = icon
        , variant = Button.Ghost
        , size = Button.Icon
        , shape = Button.Circle
        , disabled = isDisabled
        , onPress = action
        }
        []


{-| Skipping is offered forwards only, so there is nowhere to go from the end of
the race.
-}
viewSkipControls : (Replay.Msg -> msg) -> Clock.State -> Html msg
viewSkipControls toReplayMsg state =
    let
        skipItem label duration =
            { label = label
            , disabled = state == Finished
            , onPress = toReplayMsg (Replay.SkipTime duration)
            }
    in
    ButtonGroup.view
        { items =
            [ skipItem "+10s" (10 * 1000)
            , skipItem "+1m" (60 * 1000)
            , skipItem "+1h" (60 * 60 * 1000)
            ]
        }
        []


viewSpeedControls : (Replay.Msg -> msg) -> Clock.PlaybackSpeed -> Html msg
viewSpeedControls toReplayMsg currentSpeed =
    let
        speedItem label speed =
            { label = label
            , active = currentSpeed == speed
            , disabled = False
            , onSelect = toReplayMsg (Replay.SetPlaybackSpeed speed)
            }
    in
    ToggleGroup.view
        { items =
            [ speedItem "1×" Clock.Speed1x
            , speedItem "10×" Clock.Speed10x
            , speedItem "60×" Clock.Speed60x
            ]
        }
        []


viewProgressBar : (Replay.Msg -> msg) -> Replay.Model -> Html msg
viewProgressBar toReplayMsg ({ playback, race } as replay) =
    let
        elapsed =
            Clock.getElapsed playback

        lapCount =
            Replay.lapCount replay

        remaining =
            Race.timeToFlagAt { elapsed = elapsed } race
    in
    div [ Attributes.class "flex flex-col gap-2 flex-1 min-w-0 text-xs font-medium tabular-nums opacity-70" ]
        [ div [ Attributes.class "flex justify-between" ]
            [ div [] [ text (Clock.toString playback) ]
            , div [] [ text ("Lap " ++ String.fromInt lapCount ++ " / " ++ String.fromInt race.lapTotal) ]
            , div [] [ text (Duration.toString remaining |> dropRight 4) ]
            ]
        , Slider.view
            { min = 0
            , max = race.lapTotal
            , value = lapCount
            , onChange = Replay.SetCount >> toReplayMsg
            }
            []
        ]
