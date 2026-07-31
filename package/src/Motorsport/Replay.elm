module Motorsport.Replay exposing
    ( Model, empty, fromEntrants
    , Msg(..), update
    , lapCount
    )

{-| A race, and where playback has got to in it.

Two fields, and only one of them moves. `race` is settled when the data loads;
`playback` is the head running over it. Nothing derived is kept here -- what the
cars are doing at the current moment is a function of `race` and the elapsed time,
worked out where it is needed.

@docs Model, empty, fromEntrants
@docs Msg, update
@docs lapCount

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


{-| A replay of no race at all, for before one has loaded.
-}
empty : Model
empty =
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
lapCount : Model -> Int
lapCount m =
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

        SetCount wanted ->
            if wanted >= 0 && wanted <= m.race.lapTotal then
                moveToLap wanted m

            else
                m

        NextLap ->
            let
                current =
                    lapCount m
            in
            if current < m.race.lapTotal then
                moveToLap (current + 1) m

            else
                m

        PreviousLap ->
            let
                current =
                    lapCount m
            in
            if current > 0 then
                moveToLap (current - 1) m

            else
                m


moveTo : Duration -> Model -> Model
moveTo elapsed m =
    { m | playback = Clock.setElapsed elapsed m.playback }


moveToLap : Int -> Model -> Model
moveToLap wanted m =
    moveTo (Race.elapsedAtLapCount wanted m.race) m
