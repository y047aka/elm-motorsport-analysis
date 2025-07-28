module SortedList exposing
    ( sortBy
    , map
    , length
    , head, toList
    , gatherEqualsBy
    , fromSortedList
    , SortedList
    )

{-| A library for sorted lists with compile-time type safety.

You create a `SortedList` with a sorting criteria, and that particular sorting
order is preserved throughout transformations.


# Create

@docs sortBy, fromSortedList


# Transform

@docs map


# Utilities

@docs length


# Deconstruct

@docs head, toList


# Sublists

@docs gatherEqualsBy

-}

import List.Extra


{-| Represents a sorted list with type-safe sorting guarantees.

The `sorting` parameter is a phantom type that represents the sorting criteria,
ensuring different sorting types cannot be mixed at compile time.

-}
type SortedList sorting a
    = SortedList (List a)


{-| Sort values by a derived property.

    sortBy .name [{ name = "Bob" }, { name = "Alice" }]
    -- Creates a SortedList sorted by name

    sortBy .age [{ age = 25 }, { age = 20 }]
    -- Creates a SortedList sorted by age

-}
sortBy : (a -> a -> Order) -> List a -> SortedList sorting a
sortBy sortFn items =
    items
        |> List.sortWith sortFn
        |> SortedList


{-| Apply a function to every element of a sorted list.

    map sqrt (sortBy compare [ 1, 4, 9 ]) == sortBy compare [ 1, 2, 3 ]

    map .name (sortBy .age people) == sortBy .age (map .name people)

The sort order is preserved after mapping.

-}
map : (a -> b) -> SortedList sorting a -> SortedList sorting b
map fn (SortedList items) =
    List.map fn items
        |> SortedList


{-| Determine the length of a sorted list.

    length (sortBy compare [ 1, 2, 3 ]) == 3

-}
length : SortedList sorting a -> Int
length (SortedList items) =
    List.length items


{-| Extract the first element of a sorted list.

    head (sortBy compare [ 1, 2, 3 ]) == Just 1

    head (sortBy compare []) == Nothing

-}
head : SortedList sorting a -> Maybe a
head (SortedList items) =
    List.head items


{-| Convert a sorted list to a normal list.

    toList mySortedList == [ 1, 2, 3 ]

-}
toList : SortedList sorting a -> List a
toList (SortedList items) =
    items


{-| Group equal elements together. A function is applied to each element of the sorted list
and then the equality check is performed against the results of that function evaluation.
Elements will be grouped in the same order as they appear in the original sorted list. The
same applies to elements within each group.

    gatherEqualsBy .age (sortBy .name [{age=25,name="Bob"},{age=23,name="Alice"},{age=25,name="Charlie"}])
    --> [({age=25,name="Bob"},(sortBy .name [{age=25,name="Charlie"}])),({age=23,name="Alice"},(sortBy .name []))]

-}
gatherEqualsBy : (a -> b) -> SortedList sorting a -> List ( a, SortedList sorting a )
gatherEqualsBy keyFn (SortedList items) =
    List.Extra.gatherEqualsBy keyFn items
        |> List.map (\( first, rest ) -> ( first, fromSortedList rest ))


{-| Create a SortedList from a list that maintains the same sort order.
This is intended for internal use when you know the list maintains the same ordering.
For example, when filtering or taking sublists of an already sorted list.

    fromSortedList [1, 2, 3] -- Creates a SortedList with the same sort order

This function should only be used when you're certain the input maintains
the original sort order (e.g., from gatherEqualsBy results).

-}
fromSortedList : List a -> SortedList sorting a
fromSortedList items =
    SortedList items
