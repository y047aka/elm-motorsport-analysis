module Motorsport.Clock exposing
    ( Model, State(..), PlaybackSpeed(..), init
    , Msg(..), update
    , setElapsed, setPlaybackSpeed
    , toString
    , getElapsed
    , defaultSpeed
    , calcElapsed
    )

{-|

@docs Model, State, PlaybackSpeed, init


## Running the clock

These need to know what time it is now, so they take a `Posix`.

@docs Msg, update


## Moving the clock

These do not: where the head goes, and how fast it moves from there, are settled
without reference to the wall clock.

@docs setElapsed, setPlaybackSpeed


## Reading the clock

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


{-| Put the playback head at a given point in the race.
-}
setElapsed : Duration -> Model -> Model
setElapsed duration m =
    case m.state of
        -- Moving the clock before the race has been started leaves it
        -- stopped, at the moment asked for -- the same state as pausing
        -- there. Ignoring it instead would leave the clock reading zero
        -- while the rest of the replay had moved on.
        Initial ->
            { m | state = Paused duration }

        -- A running clock is re-anchored on the last time it was ticked, the
        -- same way changing speed re-anchors it. Keeping the old anchor would
        -- leave the head at the moment asked for *plus* however long playback
        -- had been running, which grows the longer the race has been playing
        -- and is multiplied by the playback speed.
        Started _ { now } ->
            { m | state = Started duration { now = now, startedAt = now } }

        Paused _ ->
            { m | state = Paused duration }

        Finished ->
            m


{-| Change how fast playback runs, leaving the head where it is.

A running clock is re-anchored on the last time it was ticked, which is the most
recent moment it knows about -- so the elapsed it reports does not jump.

-}
setPlaybackSpeed : PlaybackSpeed -> Model -> Model
setPlaybackSpeed newSpeed m =
    if newSpeed == m.playbackSpeed then
        m

    else
        case m.state of
            Started splitTime { now, startedAt } ->
                { m
                    | playbackSpeed = newSpeed
                    , state =
                        Started (calcElapsed startedAt now splitTime m.playbackSpeed)
                            { now = now, startedAt = now }
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
