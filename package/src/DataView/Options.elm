module DataView.Options exposing
    ( SortingOption(..), FilteringOption(..), SelectingOption(..), DraggingOption(..), PaginationOption(..), FillOption(..), Options(..)
    , defaultOptions
    , sorting, filtering, selecting, dragging, pagination, fill
    )

{-| Autotable options, allows configuration and toggling of features.


# Types

@docs SortingOption, FilteringOption, SelectingOption, DraggingOption, PaginationOption, FillOption, Options


# Defaults

@docs defaultOptions


# Accessors

@docs sorting, filtering, selecting, dragging, pagination, fill

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


{-| Toggle column re-ordering.
-}
type DraggingOption
    = Dragging
    | NoDragging


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
    = Options SortingOption FilteringOption SelectingOption DraggingOption PaginationOption FillOption


{-| Some nice defaults.
-}
defaultOptions : Options
defaultOptions =
    Options Sorting Filtering Selecting Dragging (Pagination 10) (Fill 10)


{-| Access sorting option.
-}
sorting : Options -> SortingOption
sorting (Options s _ _ _ _ _) =
    s


{-| Access filtering option.
-}
filtering : Options -> FilteringOption
filtering (Options _ f _ _ _ _) =
    f


{-| Access selecting option.
-}
selecting : Options -> SelectingOption
selecting (Options _ _ s _ _ _) =
    s


{-| Access dragging option.
-}
dragging : Options -> DraggingOption
dragging (Options _ _ _ d _ _) =
    d


{-| Access pagination option.
-}
pagination : Options -> PaginationOption
pagination (Options _ _ _ _ p _) =
    p


{-| Access fill option.
-}
fill : Options -> FillOption
fill (Options _ _ _ _ _ f) =
    f
