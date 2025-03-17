module DataView.Options exposing
    ( SortingOption(..), FilteringOption(..), SelectingOption(..), PaginationOption(..), Options
    , defaultOptions
    )

{-| Autotable options, allows configuration and toggling of features.


# Types

@docs SortingOption, FilteringOption, SelectingOption, PaginationOption, Options


# Defaults

@docs defaultOptions

-}


{-| Toggle column sorting.
-}
type SortingOption
    = Sorting
    | NoSorting


{-| Toggle column filtering.
-}
type FilteringOption
    = Filtering
    | NoFiltering


{-| Toggle row selection.
-}
type SelectingOption
    = Selecting
    | NoSelecting


{-| Configure pagination.
-}
type PaginationOption
    = NoPagination
    | Pagination Int


{-| Options to be passed to the table.
-}
type alias Options =
    { sorting : SortingOption
    , filtering : FilteringOption
    , selecting : SelectingOption
    , pagination : PaginationOption
    }


{-| Some nice defaults.
-}
defaultOptions : Options
defaultOptions =
    { sorting = Sorting
    , filtering = Filtering
    , selecting = Selecting
    , pagination = Pagination 10
    }
