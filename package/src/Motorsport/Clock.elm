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

import Motorsport.Instant as Instant exposing (Instant)
import Time exposing (Posix, posixToMillis)


type PlaybackSpeed
    = Speed1x
    | Speed10x
    | Speed60x


type State
    = Initial
    | Started Instant { now : Posix, startedAt : Posix }
    | Paused Instant
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
                    { m | state = Started Instant.raceStart { now = now, startedAt = now } }

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


{-| Put the playback head at a given moment of the race.
-}
setElapsed : Instant -> Model -> Model
setElapsed instant m =
    case m.state of
        -- Moving the clock before the race has been started leaves it
        -- stopped, at the moment asked for -- the same state as pausing
        -- there. Ignoring it instead would leave the clock reading zero
        -- while the rest of the replay had moved on.
        Initial ->
            { m | state = Paused instant }

        -- Re-anchored like `setPlaybackSpeed`. Keeping the old anchor would put
        -- the head at the moment asked for *plus* however long playback had been
        -- running, times the speed.
        Started _ { now } ->
            { m | state = Started instant { now = now, startedAt = now } }

        Paused _ ->
            { m | state = Paused instant }

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
                |> (Instant.toString >> String.dropRight 4)

        Paused splitTime ->
            (Instant.toString >> String.dropRight 4) splitTime

        Finished ->
            "00:00:00"


getElapsed : Model -> Instant
getElapsed m =
    case m.state of
        Initial ->
            Instant.raceStart

        Started splitTime { now, startedAt } ->
            calcElapsed startedAt now splitTime m.playbackSpeed

        Paused splitTime ->
            splitTime

        Finished ->
            Instant.raceStart



-- HELPERS


diff : Posix -> Posix -> Int
diff a b =
    posixToMillis b - posixToMillis a


calcElapsed : Posix -> Posix -> Instant -> PlaybackSpeed -> Instant
calcElapsed startedAt now splitTime playbackSpeed =
    let
        speed =
            speedToMultiplier playbackSpeed
    in
    Instant.add (diff startedAt now * speed) splitTime
