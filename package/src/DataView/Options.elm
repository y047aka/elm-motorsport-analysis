module DataView.Options exposing
    ( SortingOption(..), FilteringOption(..), SelectingOption(..), PaginationOption(..), FillOption(..), Options(..)
    , defaultOptions
    , sorting, filtering, selecting, pagination, fill
    )

{-| Autotable options, allows configuration and toggling of features.


# Types

@docs SortingOption, FilteringOption, SelectingOption, PaginationOption, FillOption, Options


# Defaults

@docs defaultOptions


# Accessors

@docs sorting, filtering, selecting, pagination, fill

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


{-| Configure empty row fill.
-}
type FillOption
    = NoFill
    | Fill Int


{-| Options to be passed to the table.
-}
type Options
    = Options SortingOption FilteringOption SelectingOption PaginationOption FillOption


{-| Some nice defaults.
-}
defaultOptions : Options
defaultOptions =
    Options Sorting Filtering Selecting (Pagination 10) (Fill 10)


{-| Access sorting option.
-}
sorting : Options -> SortingOption
sorting (Options s _ _ _ _) =
    s


{-| Access filtering option.
-}
filtering : Options -> FilteringOption
filtering (Options _ f _ _ _) =
    f


{-| Access selecting option.
-}
selecting : Options -> SelectingOption
selecting (Options _ _ s _ _) =
    s


{-| Access pagination option.
-}
pagination : Options -> PaginationOption
pagination (Options _ _ _ p _) =
    p


{-| Access fill option.
-}
fill : Options -> FillOption
fill (Options _ _ _ _ f) =
    f
