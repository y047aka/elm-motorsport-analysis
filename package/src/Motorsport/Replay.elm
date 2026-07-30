module Motorsport.Replay exposing
    ( Model, placeholder, fromEntrants
    , Msg(..), update
    , lapCountAt
    )

{-| A race, and where playback has got to in it.

Two fields, and only one of them moves. `race` is settled when the data loads;
`playback` is the head running over it. Nothing derived is kept here -- what the
cars are doing at the current moment is a function of `race` and the elapsed time,
worked out where it is needed.

@docs Model, placeholder, fromEntrants
@docs Msg, update
@docs lapCountAt

-}

import Motorsport.Clock as Clock
import Motorsport.Duration exposing (Duration)
import Motorsport.Race as Race exposing (Race)
import Motorsport.Race.Entrant exposing (Entrant)
import Time exposing (Posix)



-- MODEL


type alias Model =
    { race : Race
    , playback : Clock.Model
    }


{-| A race with nothing in it, to hold the place of one that has not loaded yet.
-}
placeholder : Model
placeholder =
    { race = Race.empty
    , playback = Clock.init
    }


fromEntrants : List Entrant -> Model
fromEntrants entrants =
    { race = Race.fromEntrants entrants
    , playback = Clock.init
    }


{-| The lap counter as it reads now.

Not a field: the race knows when the counter goes up, so where the playback head
sits is enough to say what it reads.

-}
lapCountAt : Model -> Int
lapCountAt m =
    Race.lapCountAt { elapsed = Clock.getElapsed m.playback } m.race



-- UPDATE


type Msg
    = Start Posix
    | Pause Posix
    | Finish Posix
    | Tick Posix
    | SkipTime Duration
    | SetCount Int
    | NextLap
    | PreviousLap
    | SetPlaybackSpeed Clock.PlaybackSpeed


update : Msg -> Model -> Model
update msg m =
    case msg of
        Start now ->
            { m | playback = Clock.update now Clock.Start m.playback }

        Tick now ->
            case m.playback.state of
                Clock.Started splitTime { startedAt } ->
                    if Clock.calcElapsed startedAt now splitTime m.playback.playbackSpeed < m.race.timeLimit then
                        { m | playback = Clock.update now Clock.Tick m.playback }

                    else
                        m

                _ ->
                    m

        Pause now ->
            { m | playback = Clock.update now Clock.Pause m.playback }

        Finish now ->
            { m | playback = Clock.update now Clock.Finish m.playback }

        SetPlaybackSpeed speed ->
            { m | playback = Clock.setPlaybackSpeed speed m.playback }

        SkipTime duration ->
            let
                elapsed =
                    Clock.getElapsed m.playback
            in
            -- Skipping is offered forwards, and stops once the race is over.
            if elapsed < m.race.timeLimit then
                moveTo (elapsed + duration) m

            else
                m

        SetCount lapCount ->
            if lapCount >= 0 && lapCount <= m.race.lapTotal then
                moveToLap lapCount m

            else
                m

        NextLap ->
            let
                lapCount =
                    lapCountAt m
            in
            if lapCount < m.race.lapTotal then
                moveToLap (lapCount + 1) m

            else
                m

        PreviousLap ->
            let
                lapCount =
                    lapCountAt m
            in
            if lapCount > 0 then
                moveToLap (lapCount - 1) m

            else
                m


moveTo : Duration -> Model -> Model
moveTo elapsed m =
    { m | playback = Clock.setElapsed elapsed m.playback }


moveToLap : Int -> Model -> Model
moveToLap lapCount m =
    moveTo (Race.elapsedAtLapCount lapCount m.race) m
