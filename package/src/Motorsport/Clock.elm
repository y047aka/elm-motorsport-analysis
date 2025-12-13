module Motorsport.Clock exposing
    ( Model, State(..), PlaybackSpeed(..), init
    , Msg(..), update
    , toString
    , getElapsed
    , defaultSpeed
    , calcElapsed
    )

{-|

@docs Model, State, PlaybackSpeed, init
@docs Msg, update
@docs toString
@docs getElapsed
@docs defaultSpeed
@docs calcElapsed

-}

import Motorsport.Duration as Duration exposing (Duration)
import Time exposing (Posix, posixToMillis)


type PlaybackSpeed
    = Speed1x
    | Speed10x
    | Speed60x


type State
    = Initial
    | Started Duration { now : Posix, startedAt : Posix }
    | Paused Duration
    | Finished


type alias Model =
    { state : State
    , playbackSpeed : PlaybackSpeed
    }


init : Model
init =
    { state = Initial
    , playbackSpeed = defaultSpeed
    }


defaultSpeed : PlaybackSpeed
defaultSpeed =
    Speed1x


speedToMultiplier : PlaybackSpeed -> Int
speedToMultiplier speed =
    case speed of
        Speed1x ->
            1

        Speed10x ->
            10

        Speed60x ->
            60


type Msg
    = Start
    | Tick
    | Pause
    | Finish
    | Set Duration
    | SetPlaybackSpeed PlaybackSpeed


update : Posix -> Msg -> Model -> Model
update now msg m =
    case msg of
        Start ->
            case m.state of
                Initial ->
                    { m | state = Started 0 { now = now, startedAt = now } }

                Paused splitTime ->
                    { m | state = Started splitTime { now = now, startedAt = now } }

                _ ->
                    m

        Tick ->
            case m.state of
                Started splitTime posix ->
                    { m | state = Started splitTime { posix | now = now } }

                _ ->
                    m

        Pause ->
            case m.state of
                Started splitTime { startedAt } ->
                    { m | state = Paused (calcElapsed startedAt now splitTime m.playbackSpeed) }

                _ ->
                    m

        Finish ->
            { m | state = Finished }

        Set duration ->
            case m.state of
                Started _ timer ->
                    { m | state = Started duration timer }

                Paused _ ->
                    { m | state = Paused duration }

                _ ->
                    m

        SetPlaybackSpeed newSpeed ->
            if newSpeed == m.playbackSpeed then
                m

            else
                case m.state of
                    Started splitTime { startedAt } ->
                        let
                            currentElapsed =
                                calcElapsed startedAt now splitTime m.playbackSpeed
                        in
                        { m
                            | playbackSpeed = newSpeed
                            , state = Started currentElapsed { now = now, startedAt = now }
                        }

                    _ ->
                        { m | playbackSpeed = newSpeed }


toString : Model -> String
toString m =
    case m.state of
        Initial ->
            "00:00:00"

        Started splitTime { now, startedAt } ->
            calcElapsed startedAt now splitTime m.playbackSpeed
                |> (Duration.toString >> String.dropRight 4)

        Paused splitTime ->
            (Duration.toString >> String.dropRight 4) splitTime

        Finished ->
            "00:00:00"


getElapsed : Model -> Int
getElapsed m =
    case m.state of
        Initial ->
            0

        Started splitTime { now, startedAt } ->
            calcElapsed startedAt now splitTime m.playbackSpeed

        Paused splitTime ->
            splitTime

        Finished ->
            0



-- HELPERS


diff : Posix -> Posix -> Int
diff a b =
    posixToMillis b - posixToMillis a


calcElapsed : Posix -> Posix -> Duration -> PlaybackSpeed -> Int
calcElapsed startedAt now splitTime playbackSpeed =
    let
        speed =
            speedToMultiplier playbackSpeed
    in
    (diff startedAt now * speed) + splitTime
