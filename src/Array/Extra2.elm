module Array.Extra2 exposing (sortBy)

import Array exposing (Array)


sortBy : (a -> comparable) -> Array a -> Array a
sortBy f =
    Array.toList >> List.sortBy f >> Array.fromList
