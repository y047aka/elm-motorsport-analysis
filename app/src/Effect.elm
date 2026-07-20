module Effect exposing
    ( Effect
    , none, batch
    , sendCmd, sendMsg
    , sendSharedMsg
    , pushRoute, replaceRoute, loadExternal, back
    , map, toCmd
    )

{-| The `Effect` type describes side-effects a page (or the shared model) wants
to perform, without having direct access to the `Browser.Navigation.Key` or the
top-level `Msg` type. This mirrors the pattern popularised by elm-spa / elm-land
and replaces elm-pages' `Effect`.

@docs Effect
@docs none, batch
@docs sendCmd, sendMsg
@docs sendSharedMsg
@docs pushRoute, replaceRoute, loadExternal, back
@docs map, toCmd

-}

import Browser.Navigation as Nav
import Route exposing (Route)
import Shared.Msg
import Task


{-| -}
type Effect msg
    = None
    | Batch (List (Effect msg))
    | SendCmd (Cmd msg)
    | SendSharedMsg Shared.Msg.Msg
    | PushRoute Route
    | ReplaceRoute Route
    | LoadExternal String
    | Back


{-| -}
none : Effect msg
none =
    None


{-| -}
batch : List (Effect msg) -> Effect msg
batch =
    Batch


{-| Run a `Cmd` as an effect. -}
sendCmd : Cmd msg -> Effect msg
sendCmd =
    SendCmd


{-| Dispatch a `msg` on the next update cycle. -}
sendMsg : msg -> Effect msg
sendMsg msg =
    SendCmd (Task.succeed msg |> Task.perform identity)


{-| Ask the shared model to handle a message. Pages use this to load data or to
delegate to shared state (e.g. race control). -}
sendSharedMsg : Shared.Msg.Msg -> Effect msg
sendSharedMsg =
    SendSharedMsg


{-| Navigate to a route, pushing a new history entry. -}
pushRoute : Route -> Effect msg
pushRoute =
    PushRoute


{-| Navigate to a route, replacing the current history entry. -}
replaceRoute : Route -> Effect msg
replaceRoute =
    ReplaceRoute


{-| Load an external URL (leaves the SPA). -}
loadExternal : String -> Effect msg
loadExternal =
    LoadExternal


{-| Go back one entry in history. -}
back : Effect msg
back =
    Back


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

        PushRoute route ->
            PushRoute route

        ReplaceRoute route ->
            ReplaceRoute route

        LoadExternal url ->
            LoadExternal url

        Back ->
            Back


{-| Interpret an `Effect` into a real `Cmd`. Called from `Main`, which owns the
navigation key and the top-level `Msg` type. -}
toCmd :
    { key : Nav.Key
    , fromPageMsg : pageMsg -> mainMsg
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

        PushRoute route ->
            Nav.pushUrl options.key (Route.toString route)

        ReplaceRoute route ->
            Nav.replaceUrl options.key (Route.toString route)

        LoadExternal url ->
            Nav.load url

        Back ->
            Nav.back options.key 1
