module View.PlaybackControls exposing (view)

{-| Playback controls: play/pause, skip, the flag the field is under, the
progress bar and the speed selector.

Driven purely by a `Replay.Model`. Play/pause are surfaced as dedicated
callbacks because the caller resolves them against `Time.now`; every other
interaction is forwarded as a `Replay.Msg`.

@docs view

-}

import Html exposing (Html, div, text)
import Html.Attributes as Attributes exposing (attribute)
import Html.Lazy
import Motorsport.Clock as Clock exposing (State(..))
import Motorsport.Duration as Duration
import Motorsport.Flag as Flag exposing (Flag(..))
import Motorsport.Instant as Instant
import Motorsport.Race as Race exposing (Race)
import Motorsport.Replay as Replay
import UI.Shadcn.Button as Button
import UI.Shadcn.Slider as Slider
import UI.Shadcn.ToggleGroup as ToggleGroup


view :
    { replay : Replay.Model
    , onStart : msg
    , onPause : msg
    , toReplayMsg : Replay.Msg -> msg
    }
    -> Html msg
view config =
    div [ Attributes.class "flex items-center gap-6" ]
        [ div [ Attributes.class "flex items-center gap-2" ]
            [ viewBackButton config.toReplayMsg config.replay.playback.state
            , viewPlayPauseButton config
            , viewForwardButton config.toReplayMsg config.replay.playback.state
            ]
        , flagChip (Race.flagAt { elapsed = Clock.getElapsed config.replay.playback } config.replay.race)
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


{-| Neither button moves at the end of the race: nothing is playing there to
rewind, and there is nothing left to skip to.
-}
viewBackButton : (Replay.Msg -> msg) -> Clock.State -> Html msg
viewBackButton toReplayMsg state =
    viewJumpButton "-10s" (Replay.BackTime (10 * 1000)) state toReplayMsg


viewForwardButton : (Replay.Msg -> msg) -> Clock.State -> Html msg
viewForwardButton toReplayMsg state =
    viewJumpButton "+10s" (Replay.SkipTime (10 * 1000)) state toReplayMsg


viewJumpButton :
    String
    -> Replay.Msg
    -> Clock.State
    -> (Replay.Msg -> msg)
    -> Html msg
viewJumpButton label msg state toReplayMsg =
    Button.view
        { label = label
        , variant = Button.Ghost
        , size = Button.Icon
        , shape = Button.Circle
        , disabled = state == Finished
        , onPress = toReplayMsg msg
        }
        []


flagChip : Flag -> Html msg
flagChip flag =
    div
        [ Attributes.class "w-32 shrink-0 rounded-md px-2 py-1 text-center text-xs font-medium whitespace-nowrap"
        , Attributes.class (chipColor flag)
        ]
        [ text (Flag.toString flag) ]


chipColor : Flag -> String
chipColor flag =
    case flag of
        GreenFlag ->
            "bg-green-500/15 text-green-400"

        FullCourseYellow ->
            "bg-yellow-400 text-yellow-950"

        SafetyCar ->
            "bg-orange-500 text-orange-950"

        RedFlag ->
            "bg-red-600 text-white"


bandColor : Flag -> String
bandColor flag =
    case flag of
        GreenFlag ->
            "bg-green-600"

        FullCourseYellow ->
            "bg-yellow-400"

        SafetyCar ->
            "bg-orange-500"

        RedFlag ->
            "bg-red-600"


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
viewProgressBar toReplayMsg { playback, race } =
    let
        elapsed =
            Clock.getElapsed playback

        finishedAt =
            Instant.toDuration playback.finishedAt

        remaining =
            Race.timeToFlagAt { elapsed = elapsed } race

        progress =
            percentOf finishedAt (Instant.toDuration elapsed)
    in
    div [ Attributes.class "flex items-center gap-3 flex-1 min-w-0 text-xs font-medium tabular-nums" ]
        [ div [ Attributes.class "opacity-70" ] [ text (Clock.toString playback) ]
        , div [ Attributes.class "relative flex-1 min-w-0" ]
            -- Inset by half the thumb: the thumb is aligned to the track's
            -- edges, so its centre runs over the width less one thumb.
            [ div
                [ Attributes.class "absolute inset-x-0.75 top-1/2 -translate-y-1/2 h-4 rounded-sm overflow-hidden"
                , Attributes.class (bandColor GreenFlag)
                ]
                [ Html.Lazy.lazy2 flagBands finishedAt race
                , div
                    [ Attributes.class "absolute inset-y-0 right-0 bg-background/60"
                    , attribute "style" ("left: " ++ progress ++ "%")
                    ]
                    []
                ]
            , Slider.view
                { min = 0
                , max = ceiling (toFloat finishedAt / 1000)
                , value = Instant.toDuration elapsed // 1000
                , onChange = (*) 1000 >> Instant.fromDuration >> Replay.SetElapsed >> toReplayMsg
                }
                [ Attributes.class "relative block [&_[data-slot=slider-track]]:bg-transparent [&_[data-slot=slider-range]]:bg-transparent"
                , Attributes.class "[&_[data-slot=slider-thumb]]:h-6 [&_[data-slot=slider-thumb]]:w-1.5 [&_[data-slot=slider-thumb]]:rounded-sm"
                ]
            ]
        , div [ Attributes.class "opacity-70" ] [ text (Duration.toStringToSeconds remaining) ]
        ]


{-| Built once per round: the thunk's arguments are a number and the race,
neither of which playback moves.

A yellow can be a minute of a day's race, narrower than a pixel, so every band
is drawn at least a few wide.

-}
flagBands : Int -> Race -> Html msg
flagBands finishedAt race =
    Race.flagPeriods race
        -- Green is the strip's own colour: the race runs under it before any
        -- flag has been shown, which no period covers.
        |> List.filter (\period -> period.flag /= GreenFlag)
        |> List.map
            (\period ->
                let
                    from =
                        Instant.toDuration period.from

                    until =
                        period.until |> Maybe.map Instant.toDuration |> Maybe.withDefault finishedAt
                in
                div
                    [ Attributes.class "absolute inset-y-0 min-w-[3px]"
                    , Attributes.class (bandColor period.flag)
                    , attribute "style"
                        ("left: " ++ percentOf finishedAt from ++ "%; width: " ++ percentOf finishedAt (until - from) ++ "%")
                    ]
                    []
            )
        |> div []


percentOf : Int -> Int -> String
percentOf whole part =
    if whole <= 0 then
        "0"

    else
        String.fromFloat (100 * toFloat (clamp 0 whole part) / toFloat whole)
