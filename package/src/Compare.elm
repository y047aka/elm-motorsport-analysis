module Compare exposing (by)

{-| Building comparators out of getters.

@docs by

-}


{-| Compare two values by something read off each of them.

    List.sortWith (Compare.by .position) entries

-}
by : (a -> comparable) -> a -> a -> Order
by getter a b =
    compare (getter a) (getter b)
