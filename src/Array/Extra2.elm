module Array.Extra2 exposing (find, findMap, sortBy)

import Array exposing (Array)


sortBy : (a -> comparable) -> Array a -> Array a
sortBy f =
    Array.toList >> List.sortBy f >> Array.fromList


find : (a -> Bool) -> Array a -> Maybe a
find predicate array =
    findHelp predicate array 0 (Array.length array) Nothing


findHelp : (a -> Bool) -> Array a -> Int -> Int -> Maybe a -> Maybe a
findHelp predicate array index until acc =
    if index >= until then
        acc

    else
        let
            element =
                Array.get index array
        in
        case Maybe.map predicate element of
            Just True ->
                element

            _ ->
                findHelp predicate array (index + 1) until acc


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
