module Motorsport.Replay exposing
    ( Model, fromCars
    , Msg(..), update
    , lapCount
    )

{-| A race, and where playback has got to in it.

Two fields, and only one of them moves. `race` is settled when the data loads;
`playback` is the head running over it. Nothing derived is kept here -- what the
cars are doing at the current moment is a function of `race` and the elapsed time,
worked out where it is needed.

@docs Model, fromCars
@docs Msg, update
@docs lapCount

-}

import Motorsport.Clock as Clock
import Motorsport.Duration exposing (Duration)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Race as Race exposing (Race)
import Motorsport.Race.Car exposing (Car)
import Time exposing (Posix)



-- MODEL


type alias Model =
    { race : Race
    , playback : Clock.Model
    }


fromCars : { timeLimit : Instant, finishedAt : Instant, index : Race.Index } -> List Car -> Model
fromCars { timeLimit, finishedAt, index } cars =
    { race = Race.fromCars { timeLimit = timeLimit, index = index } cars
    , playback = Clock.init { finishedAt = finishedAt }
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
            { m | playback = Clock.update now Clock.Tick m.playback }

        Pause now ->
            { m | playback = Clock.update now Clock.Pause m.playback }

        SetPlaybackSpeed speed ->
            { m | playback = Clock.setPlaybackSpeed speed m.playback }

        SkipTime duration ->
            -- The clock clamps: more than there is left lands on the end.
            moveTo (Instant.add duration (Clock.getElapsed m.playback)) m

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


moveTo : Instant -> Model -> Model
moveTo elapsed m =
    { m | playback = Clock.setElapsed elapsed m.playback }


moveToLap : Int -> Model -> Model
moveToLap wanted m =
    moveTo (Race.elapsedAtLapCount wanted m.race) m
