module Motorsport.Ordering exposing (ByPosition, byPosition)

{-| Motorsport-specific ordering types

This module defines phantom types for motorsport-specific ordering criteria.


# Position Ordering

@docs ByPosition, byPosition

-}

import Motorsport.Utils exposing (compareBy)
import SortedList exposing (SortedList)


{-| Phantom type representing position-based ordering

This type ensures that collections ordered by racing position
cannot be mixed with other ordering types at compile time.

-}
type ByPosition
    = ByPosition Never


{-| Create a position-ordered collection from items with a position field

    items : List { position : Int, name : String }

    sortedItems : SortedList ByPosition { position : Int, name : String }
    sortedItems =
        byPosition items

-}
byPosition : List { a | position : Int } -> SortedList ByPosition { a | position : Int }
byPosition items =
    SortedList.sortBy (compareBy .position) items
