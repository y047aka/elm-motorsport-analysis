module Array.Extra2 exposing (find, sortBy)

import Array exposing (Array)


sortBy : (a -> comparable) -> Array a -> Array a
sortBy f =
    Array.toList >> List.sortBy f >> Array.fromList


find : (a -> Bool) -> Array a -> Maybe a
find predicate arr =
    Array.foldl
        (\item acc ->
            if acc == Nothing && predicate item then
                Just item

            else
                acc
        )
        Nothing
        arr
