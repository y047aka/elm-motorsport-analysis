module View.PlaybackControls exposing (view)

{-| Playback controls: play/pause, skip, progress bar and speed selector.

Driven purely by a `Replay.Model`. Play/pause are surfaced as dedicated
callbacks because the caller resolves them against `Time.now`; every other
interaction is forwarded as a `Replay.Msg`.

@docs view

-}

import Html.Styled exposing (Html, button, div, input, text)
import Html.Styled.Attributes as Attributes exposing (type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Motorsport.Clock as Clock exposing (State(..))
import Motorsport.Duration as Duration
import Motorsport.Instant as Instant
import Motorsport.Race.Phase as Phase
import Motorsport.Replay as Replay
import String exposing (dropRight)


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

                -- Nothing left to play. Offering ▶ rather than ■ says which
                -- way the head is stuck, and disabling it saves the round trip
                -- through Started that the next tick would undo.
                Finished ->
                    ( "▶", onStart, True )
    in
    button
        [ onClick action
        , Attributes.disabled isDisabled
        , Attributes.class "btn btn-circle btn-sm btn-ghost text-xs"
        ]
        [ text icon ]


{-| Skipping is offered forwards only, so at the end of the race there is
nowhere for any of these to go.
-}
viewSkipControls : (Replay.Msg -> msg) -> Clock.State -> Html msg
viewSkipControls toReplayMsg state =
    let
        skipButton label duration =
            joinButton
                { label = label
                , isActive = False
                , isDisabled = state == Finished
                , onPress = toReplayMsg (Replay.SkipTime duration)
                }
    in
    div [ Attributes.class "join" ]
        [ skipButton "+10s" (10 * 1000)
        , skipButton "+1m" (60 * 1000)
        , skipButton "+1h" (60 * 60 * 1000)
        ]


viewSpeedControls : (Replay.Msg -> msg) -> Clock.PlaybackSpeed -> Html msg
viewSpeedControls toReplayMsg currentSpeed =
    div [ Attributes.class "join" ]
        [ speedSegmentButton toReplayMsg "1×" Clock.Speed1x (currentSpeed == Clock.Speed1x)
        , speedSegmentButton toReplayMsg "10×" Clock.Speed10x (currentSpeed == Clock.Speed10x)
        , speedSegmentButton toReplayMsg "60×" Clock.Speed60x (currentSpeed == Clock.Speed60x)
        ]


speedSegmentButton : (Replay.Msg -> msg) -> String -> Clock.PlaybackSpeed -> Bool -> Html msg
speedSegmentButton toReplayMsg label speed isActive =
    joinButton
        { label = label
        , isActive = isActive
        , isDisabled = False
        , onPress = toReplayMsg (Replay.SetPlaybackSpeed speed)
        }


viewProgressBar : (Replay.Msg -> msg) -> Replay.Model -> Html msg
viewProgressBar toReplayMsg ({ playback, race } as replay) =
    let
        elapsed =
            Clock.getElapsed playback

        lapCount =
            Replay.lapCount replay

        remaining =
            case Phase.at { elapsed = elapsed } race of
                Phase.Running ->
                    Instant.since { from = elapsed, to = race.timeLimit }

                Phase.Finishing ->
                    0

                Phase.Over ->
                    0
    in
    div [ Attributes.class "flex flex-col gap-2 flex-1 min-w-0 text-xs font-medium tabular-nums opacity-70" ]
        [ div [ Attributes.class "flex justify-between" ]
            [ div [] [ text (Clock.toString playback) ]
            , div [] [ text ("Lap " ++ String.fromInt lapCount ++ " / " ++ String.fromInt race.lapTotal) ]
            , div [] [ text (Duration.toString remaining |> dropRight 4) ]
            ]
        , input
            [ type_ "range"
            , Attributes.min "0"
            , Attributes.max (String.fromInt race.lapTotal)
            , value (String.fromInt lapCount)
            , onInput (String.toInt >> Maybe.withDefault 0 >> Replay.SetCount >> toReplayMsg)
            , Attributes.class "range range-xs w-full"
            ]
            []
        ]


joinButton : { label : String, isActive : Bool, isDisabled : Bool, onPress : msg } -> Html msg
joinButton { label, isActive, isDisabled, onPress } =
    button
        [ onClick onPress
        , Attributes.disabled isDisabled
        , Attributes.class
            ("join-item btn btn-sm btn-soft"
                ++ (if isActive then
                        " btn-active"

                    else
                        ""
                   )
            )
        ]
        [ text label ]
