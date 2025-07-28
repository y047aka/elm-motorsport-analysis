module NonEmptySortedList exposing
    ( sortBy
    , map
    , length
    , head, toList, toNonEmpty
    , gatherEqualsBy
    , NonEmptySortedList
    )

{-| A library for non-empty sorted lists with compile-time type safety.

This combines the guarantees of NonEmpty (always contains at least one element)
with SortedList (maintains sort order). You create a `NonEmptySortedList` with
a sorting criteria, and that particular sorting order is preserved throughout
transformations while guaranteeing the list is never empty.


# Create

@docs sortBy


# Transform

@docs map


# Utilities

@docs length


# Deconstruct

@docs head, toList, toNonEmpty


# Sublists

@docs gatherEqualsBy

-}

import List.Extra
import List.NonEmpty as NonEmpty exposing (NonEmpty)
import SortedList exposing (SortedList)


{-| Represents a non-empty sorted list with type-safe sorting guarantees.

The `sorting` parameter is a phantom type that represents the sorting criteria,
ensuring different sorting types cannot be mixed at compile time. The list is
guaranteed to contain at least one element.

-}
type NonEmptySortedList sorting a
    = NonEmptySortedList (NonEmpty a)


{-| Sort a NonEmpty list by a comparison function.

    sortBy compare (NonEmpty.fromList [3, 1, 2])
    -- Creates a NonEmptySortedList: [1, 2, 3]

    sortBy (compareBy .position) (NonEmpty.fromList [{ position = 3 }, { position = 1 }])
    -- Creates a NonEmptySortedList sorted by position: [{ position = 1 }, { position = 3 }]

-}
sortBy : (a -> a -> Order) -> NonEmpty a -> NonEmptySortedList sorting a
sortBy sortFn items =
    items
        |> NonEmpty.sortWith sortFn
        |> NonEmptySortedList


{-| Apply a function to every element of a non-empty sorted list.

    map .name (fromNonEmpty compare people)
    -- Applies .name to each person while preserving sort order

The sort order is preserved after mapping, and the non-empty guarantee is maintained.

-}
map : (a -> b) -> NonEmptySortedList sorting a -> NonEmptySortedList sorting b
map fn (NonEmptySortedList items) =
    NonEmpty.map fn items
        |> NonEmptySortedList


{-| Determine the length of a non-empty sorted list.

    length (fromNonEmpty compare (NonEmpty.fromList [ 1, 2, 3 ])) == 3

Since the list is guaranteed non-empty, length is always >= 1.

-}
length : NonEmptySortedList sorting a -> Int
length (NonEmptySortedList items) =
    NonEmpty.length items


{-| Extract the first element of a non-empty sorted list.

    head (fromNonEmpty compare (NonEmpty.fromList [ 3, 1, 2 ])) == 1

Since the list is guaranteed non-empty, this always returns a value.

-}
head : NonEmptySortedList sorting a -> a
head (NonEmptySortedList items) =
    NonEmpty.head items


{-| Convert a non-empty sorted list to a normal list.

    toList mySortedList == [ 1, 2, 3 ]

The resulting list maintains the sort order and contains at least one element.

-}
toList : NonEmptySortedList sorting a -> List a
toList (NonEmptySortedList items) =
    NonEmpty.toList items


{-| Convert a non-empty sorted list back to a NonEmpty list.

    toNonEmpty (fromNonEmpty compare nonEmptyList) == sortedNonEmptyList

The resulting NonEmpty list maintains the sort order.

-}
toNonEmpty : NonEmptySortedList sorting a -> NonEmpty a
toNonEmpty (NonEmptySortedList items) =
    items


{-| Group equal elements together. A function is applied to each element of the
non-empty sorted list and then the equality check is performed against the results
of that function evaluation. Elements will be grouped in the same order as they
appear in the original sorted list. The same applies to elements within each group.

    gatherEqualsBy .age (sortBy (compareBy .name) peopleNonEmpty)
    -- Groups people by age while maintaining the original name-based sort order
    -- Returns: List ( person, SortedList ByName person )

-}
gatherEqualsBy : (a -> b) -> NonEmptySortedList sorting a -> List ( a, SortedList sorting a )
gatherEqualsBy keyFn (NonEmptySortedList items) =
    items
        |> NonEmpty.toList
        |> List.Extra.gatherEqualsBy keyFn
        |> List.map (\( first, rest ) -> ( first, SortedList.fromSortedList rest ))
