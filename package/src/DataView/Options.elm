module DataView.Options exposing
    ( SortingOption(..), FilteringOption(..), SelectingOption(..), PaginationOption(..), Options(..)
    , defaultOptions
    , sorting, filtering, selecting, pagination
    )

{-| Autotable options, allows configuration and toggling of features.


# Types

@docs SortingOption, FilteringOption, SelectingOption, PaginationOption, Options


# Defaults

@docs defaultOptions


# Accessors

@docs sorting, filtering, selecting, pagination

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
type Options
    = Options SortingOption FilteringOption SelectingOption PaginationOption


{-| Some nice defaults.
-}
defaultOptions : Options
defaultOptions =
    Options Sorting Filtering Selecting (Pagination 10)


{-| Access sorting option.
-}
sorting : Options -> SortingOption
sorting (Options s _ _ _) =
    s


{-| Access filtering option.
-}
filtering : Options -> FilteringOption
filtering (Options _ f _ _) =
    f


{-| Access selecting option.
-}
selecting : Options -> SelectingOption
selecting (Options _ _ s _) =
    s


{-| Access pagination option.
-}
pagination : Options -> PaginationOption
pagination (Options _ _ _ p) =
    p
