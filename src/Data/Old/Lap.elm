module Data.Old.Lap exposing (Lap, fastest, fromWithoutElapsed)

import Data.Lap.WithoutElapsed exposing (WithoutElapsed)
import List.Extra


type alias Lap =
    { lapCount : Int
    , time : Float
    , elapsed : Float
    }


fastest : List { a | time : Float } -> Maybe { a | time : Float }
fastest =
    List.sortBy .time >> List.head


fromWithoutElapsed : List WithoutElapsed -> List Lap
fromWithoutElapsed laps =
    let
        elapsed laps_ i =
            laps_
                |> List.Extra.takeWhile (\d -> i + 1 >= d.lapCount)
                |> List.foldl (.time >> (+)) 0
    in
    List.indexedMap
        (\i { lapCount, time } ->
            { lapCount = lapCount
            , time = time
            , elapsed = elapsed laps i
            }
        )
        laps
