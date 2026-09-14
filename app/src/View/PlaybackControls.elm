module View.PlaybackControls exposing (view)

{-| Playback controls: play/pause, a fast-forward button that skips while
stopped, and the progress bar.

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
import UI.Shadcn.Button as Button
import UI.Shadcn.Slider as Slider


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
            , viewFastForwardButton config.toReplayMsg config.replay.playback
            ]
        , viewProgressBar config.toReplayMsg config.replay
        ]


{-| While playback runs, one press is one step up the ladder of speeds, so the
number of presses is how far from 1× it gets. Stopped, there is no speed to
step and a press skips forward instead.

`Finished` is stopped too: the clock re-anchors on a move from there, so a
press rewinds rather than doing nothing.
-}
viewFastForwardButton : (Replay.Msg -> msg) -> Clock.Model -> Html msg
viewFastForwardButton toReplayMsg playback =
    let
        running =
            case playback.state of
                Started _ _ ->
                    True

                _ ->
                    False

        ( icon, label, onPress ) =
            if running then
                ( "⏩"
                , "Faster"
                , Replay.SetPlaybackSpeed (Clock.faster playback.playbackSpeed)
                )

            else
                ( "⏭"
                , "Skip 15s"
                , Replay.SkipTime (15 * 1000)
                )
    in
    Button.view
        { label = icon
        , variant = Button.Ghost
        , size = Button.Icon
        , shape = Button.Circle
        , disabled = False
        , onPress = toReplayMsg onPress
        }
        [ Attributes.title label
        , Attributes.attribute "aria-label" label
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
            , div [] [ text (Duration.toStringToSeconds remaining) ]
            ]
        , Slider.view
            { min = 0
            , max = race.lapTotal
            , value = lapCount
            , onChange = Replay.SetCount >> toReplayMsg
            }
            []
        ]
