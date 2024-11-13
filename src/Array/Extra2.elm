module Array.Extra2 exposing (find, findMap, sortBy)

import Array exposing (Array)


sortBy : (a -> comparable) -> Array a -> Array a
sortBy f =
    Array.toList >> List.sortBy f >> Array.fromList


find : (a -> Bool) -> Array a -> Maybe a
find predicate array =
    Array.foldl
        (\item acc ->
            if acc == Nothing && predicate item then
                Just item

            else
                acc
        )
        Nothing
        array


findMap : (a -> Maybe b) -> Array a -> Maybe b
findMap f array =
    Array.foldl
        (\item acc ->
            case acc of
                Just found ->
                    Just found

                Nothing ->
                    f item
        )
        Nothing
        array
