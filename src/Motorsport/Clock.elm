module Motorsport.Clock exposing
    ( Model(..), init
    , Msg(..), update
    , Clock
    , toString
    )

{-|

@docs Model, init
@docs Msg, update

@docs Clock
@docs toString

-}

import Motorsport.Duration as Duration exposing (Duration)
import Time exposing (Posix)


type Model
    = Initial
    | Started Duration Posix
    | Paused
    | Finished


init : Model
init =
    Initial


type Msg
    = Start Posix
    | Pause
    | Finish


update : Msg -> Model -> Model
update msg m =
    case msg of
        Start now ->
            Started 0 now

        Pause ->
            Paused

        Finish ->
            Finished



-- OUTDATED


type alias Clock =
    { elapsed : Duration }


toString : Clock -> String
toString =
    .elapsed >> Duration.toString
