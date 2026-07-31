module Effect exposing
    ( Effect
    , none, batch
    , sendCmd, sendSharedMsg
    , map, toCmd
    )

{-| The `Effect` type describes side-effects a page (or the shared model) wants
to perform, without direct access to the top-level `Msg` type. This mirrors
the pattern popularised by elm-spa / elm-land and replaces elm-pages' `Effect`.

@docs Effect
@docs none, batch
@docs sendCmd, sendSharedMsg
@docs map, toCmd

-}

import Shared.Msg
import Task


{-| -}
type Effect msg
    = None
    | Batch (List (Effect msg))
    | SendCmd (Cmd msg)
    | SendSharedMsg Shared.Msg.Msg


{-| -}
none : Effect msg
none =
    None


{-| -}
batch : List (Effect msg) -> Effect msg
batch =
    Batch


{-| Run a `Cmd` as an effect.
-}
sendCmd : Cmd msg -> Effect msg
sendCmd =
    SendCmd


{-| Ask the shared model to handle a message. Pages use this to load data or to
delegate to shared state (e.g. playback).
-}
sendSharedMsg : Shared.Msg.Msg -> Effect msg
sendSharedMsg =
    SendSharedMsg


{-| -}
map : (a -> b) -> Effect a -> Effect b
map fn effect =
    case effect of
        None ->
            None

        Batch list ->
            Batch (List.map (map fn) list)

        SendCmd cmd ->
            SendCmd (Cmd.map fn cmd)

        SendSharedMsg msg ->
            SendSharedMsg msg


{-| Interpret an `Effect` into a real `Cmd`. Called from `Main`, which owns the
top-level `Msg` type.
-}
toCmd :
    { fromPageMsg : pageMsg -> mainMsg
    , fromSharedMsg : Shared.Msg.Msg -> mainMsg
    }
    -> Effect pageMsg
    -> Cmd mainMsg
toCmd options effect =
    case effect of
        None ->
            Cmd.none

        Batch list ->
            Cmd.batch (List.map (toCmd options) list)

        SendCmd cmd ->
            Cmd.map options.fromPageMsg cmd

        SendSharedMsg msg ->
            Task.succeed msg |> Task.perform options.fromSharedMsg
