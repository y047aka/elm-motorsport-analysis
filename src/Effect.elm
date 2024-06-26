module Effect exposing
    ( Effect, none, map, batch
    , fromCmd
    , toCmd
    , fetchCsv, updateRaceControl
    )

{-|

@docs Effect, none, map, batch
@docs fromCmd
@docs toCmd

@docs fetchCsv, updateRaceControl

-}

import Motorsport.RaceControl as RaceControl
import Shared
import Task


type Effect msg
    = None
    | Cmd (Cmd msg)
    | Shared Shared.Msg
    | Batch (List (Effect msg))


none : Effect msg
none =
    None


map : (a -> b) -> Effect a -> Effect b
map fn effect =
    case effect of
        None ->
            None

        Cmd cmd ->
            Cmd (Cmd.map fn cmd)

        Shared msg ->
            Shared msg

        Batch list ->
            Batch (List.map (map fn) list)


fromCmd : Cmd msg -> Effect msg
fromCmd =
    Cmd


batch : List (Effect msg) -> Effect msg
batch =
    Batch



-- Used by Main.elm


toCmd : ( Shared.Msg -> msg, pageMsg -> msg ) -> Effect pageMsg -> Cmd msg
toCmd ( fromSharedMsg, fromPageMsg ) effect =
    case effect of
        None ->
            Cmd.none

        Cmd cmd ->
            Cmd.map fromPageMsg cmd

        Shared msg ->
            Task.succeed msg
                |> Task.perform fromSharedMsg

        Batch list ->
            Cmd.batch (List.map (toCmd ( fromSharedMsg, fromPageMsg )) list)



-- Shared messages


fetchCsv : String -> Effect msg
fetchCsv =
    Shared.FetchCsv >> Shared


updateRaceControl : RaceControl.Msg -> Effect msg
updateRaceControl =
    Shared.RaceControlMsg >> Shared
