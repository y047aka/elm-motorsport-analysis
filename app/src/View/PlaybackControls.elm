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
            , viewSkipControls config.toReplayMsg
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
                    ( "■", onPause, True )
    in
    button
        [ onClick action
        , Attributes.disabled isDisabled
        , Attributes.class "btn btn-circle btn-sm btn-ghost text-xs"
        ]
        [ text icon ]


viewSkipControls : (Replay.Msg -> msg) -> Html msg
viewSkipControls toReplayMsg =
    div [ Attributes.class "join" ]
        [ joinButton "+10s" False (toReplayMsg (Replay.SkipTime (10 * 1000)))
        , joinButton "+1m" False (toReplayMsg (Replay.SkipTime (60 * 1000)))
        , joinButton "+1h" False (toReplayMsg (Replay.SkipTime (60 * 60 * 1000)))
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
    joinButton label isActive (toReplayMsg (Replay.SetPlaybackSpeed speed))


viewProgressBar : (Replay.Msg -> msg) -> Replay.Model -> Html msg
viewProgressBar toReplayMsg ({ playback, race } as replay) =
    let
        elapsed =
            Clock.getElapsed playback

        lapCount =
            Replay.lapCountAt replay

        remaining =
            race.timeLimit - elapsed
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


joinButton : String -> Bool -> msg -> Html msg
joinButton label isActive msg =
    button
        [ onClick msg
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
