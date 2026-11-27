module NonEmpty exposing (NonEmpty(..), fromList, toList)

{-| A list with at least one item.

@docs NonEmpty, fromList, toList

-}


{-| The head and the rest.

    toList (NonEmpty 1 [ 2, 3 ])
    --> [ 1, 2, 3 ]

-}
type NonEmpty a
    = NonEmpty a (List a)


{-| A list that turns out to have something in it.

    fromList []
    --> Nothing

    fromList [ "VAN", "DER", "LINDE" ]
    --> Just (NonEmpty "VAN" [ "DER", "LINDE" ])

-}
fromList : List a -> Maybe (NonEmpty a)
fromList items =
    case items of
        [] ->
            Nothing

        first :: rest ->
            Just (NonEmpty first rest)


{-| The items, head first.

    toList (NonEmpty "Kobayashi" [])
    --> [ "Kobayashi" ]

-}
toList : NonEmpty a -> List a
toList (NonEmpty first rest) =
    first :: rest
