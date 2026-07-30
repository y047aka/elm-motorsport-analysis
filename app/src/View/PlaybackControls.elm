module View.PlaybackControls exposing (view)

{-| Playback controls: play/pause, skip, progress bar and speed selector.

Driven purely by a `RaceControl.Model`. Play/pause are surfaced as dedicated
callbacks because the caller resolves them against `Time.now`; every other
interaction is forwarded as a `RaceControl.Msg`.

@docs view

-}

import Html.Styled exposing (Html, button, div, input, text)
import Html.Styled.Attributes as Attributes exposing (type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Motorsport.Clock as Clock exposing (State(..))
import Motorsport.Duration as Duration
import Motorsport.RaceControl as RaceControl
import String exposing (dropRight)


view :
    { raceControl : RaceControl.Model
    , onStart : msg
    , onPause : msg
    , toRaceControlMsg : RaceControl.Msg -> msg
    }
    -> Html msg
view config =
    div [ Attributes.class "flex items-center gap-8" ]
        [ div [ Attributes.class "flex items-center gap-2" ]
            [ viewPlayPauseButton config
            , viewSkipControls config.toRaceControlMsg
            ]
        , viewProgressBar config.toRaceControlMsg config.raceControl
        , viewSpeedControls config.toRaceControlMsg config.raceControl.playback.playbackSpeed
        ]


viewPlayPauseButton :
    { a | raceControl : RaceControl.Model, onStart : msg, onPause : msg }
    -> Html msg
viewPlayPauseButton { raceControl, onStart, onPause } =
    let
        ( icon, action, isDisabled ) =
            case raceControl.playback.state of
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


viewSkipControls : (RaceControl.Msg -> msg) -> Html msg
viewSkipControls toRaceControlMsg =
    div [ Attributes.class "join" ]
        [ joinButton "+10s" False (toRaceControlMsg (RaceControl.SkipTime (10 * 1000)))
        , joinButton "+1m" False (toRaceControlMsg (RaceControl.SkipTime (60 * 1000)))
        , joinButton "+1h" False (toRaceControlMsg (RaceControl.SkipTime (60 * 60 * 1000)))
        ]


viewSpeedControls : (RaceControl.Msg -> msg) -> Clock.PlaybackSpeed -> Html msg
viewSpeedControls toRaceControlMsg currentSpeed =
    div [ Attributes.class "join" ]
        [ speedSegmentButton toRaceControlMsg "1×" Clock.Speed1x (currentSpeed == Clock.Speed1x)
        , speedSegmentButton toRaceControlMsg "10×" Clock.Speed10x (currentSpeed == Clock.Speed10x)
        , speedSegmentButton toRaceControlMsg "60×" Clock.Speed60x (currentSpeed == Clock.Speed60x)
        ]


speedSegmentButton : (RaceControl.Msg -> msg) -> String -> Clock.PlaybackSpeed -> Bool -> Html msg
speedSegmentButton toRaceControlMsg label speed isActive =
    joinButton label isActive (toRaceControlMsg (RaceControl.SetPlaybackSpeed speed))


viewProgressBar : (RaceControl.Msg -> msg) -> RaceControl.Model -> Html msg
viewProgressBar toRaceControlMsg ({ playback, race } as raceControl) =
    let
        elapsed =
            Clock.getElapsed playback

        lapCount =
            RaceControl.lapCountAt raceControl

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
            , onInput (String.toInt >> Maybe.withDefault 0 >> RaceControl.SetCount >> toRaceControlMsg)
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
