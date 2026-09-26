module Motorsport.Replay exposing
    ( Model, fromCars
    , Msg(..), update
    )

{-| A race, and where playback has got to in it.

`race` is settled when the data loads; `playback` is the head running over it.
Nothing derived is kept here.

@docs Model, fromCars
@docs Msg, update

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


fromCars :
    { timeLimit : Instant, finishedAt : Instant, index : Race.Index }
    -> List Car
    -> Model
fromCars { timeLimit, finishedAt, index } cars =
    { race = Race.fromCars { timeLimit = timeLimit, index = index } cars
    , playback = Clock.init { finishedAt = finishedAt }
    }



-- UPDATE


type Msg
    = Start Posix
    | Pause Posix
    | Tick Posix
    | SkipTime Duration
    | BackTime Duration
    | SetElapsed Instant
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

        BackTime duration ->
            -- And `subtract` clamps the other way, at the start of the race.
            moveTo (Instant.subtract duration (Clock.getElapsed m.playback)) m

        SetElapsed elapsed ->
            moveTo elapsed m


moveTo : Instant -> Model -> Model
moveTo elapsed m =
    { m | playback = Clock.setElapsed elapsed m.playback }
