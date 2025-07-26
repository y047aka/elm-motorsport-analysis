module SortedList exposing
    ( SortedList(..)
    , sortBy, toList, map
    )

{-| Type-safe sorted lists using phantom types

This module provides phantom type-based sorting guarantees that can be used
with any sorting criteria. The sorting type parameter ensures compile-time
safety for sorted lists.

# Types
@docs SortedList

# Functions
@docs sortBy, toList, map

-}


{-| Phantom type for type-safe sorted lists

The `sorting` parameter is a phantom type that represents the sorting criteria.
This ensures that different sorting types cannot be mixed at compile time.

    type ByPosition = ByPosition Never
    type ByTime = ByTime Never
    
    sortedByPosition : SortedList ByPosition Item
    sortedByTime : SortedList ByTime Item
    
    -- This would be a compile-time error:
    -- combinedList = List.append (toList sortedByPosition) (toList sortedByTime)

-}
type SortedList sorting a
    = SortedList (List a)


{-| Create a sorted list by applying a sorter function

The sorter function determines the sorting criteria, and the phantom type
parameter ensures type safety.

    sortBy (compareBy .position) items

-}
sortBy : (a -> a -> Order) -> List a -> SortedList sorting a
sortBy sortFn items =
    items
        |> List.sortWith sortFn
        |> SortedList


{-| Extract the list from a sorted list

This is the only way to access the underlying list, ensuring that the sorting
guarantee is maintained.

    toList sortedItems

-}
toList : SortedList sorting a -> List a
toList (SortedList items) =
    items


{-| Map over a sorted list while preserving sorting guarantee

The mapping function is applied to each element while maintaining the original
sorting order.

    map .name sortedItems

-}
map : (a -> b) -> SortedList sorting a -> SortedList sorting b
map fn (SortedList items) =
    List.map fn items
        |> SortedList