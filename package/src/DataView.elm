module DataView exposing
    ( Model, Filter, Sorting, init
    , Msg(..), update
    , Config, Column
    , stringColumn, intColumn, floatColumn
    , customColumn, veryCustomColumn
    , noFiltering, noSorting
    , view
    )

{-| This library helps you create sortable tables. The crucial feature is that it
lets you own your data separately and keep it in whatever format is best for
you. This way you are free to change your data without worrying about the table
&ldquo;getting out of sync&rdquo; with the data. Having a single source of
truth is pretty great!


# Model

@docs Model, Filter, Sorting, init


# Update

@docs Msg, update


# Configuration

@docs Config, Column
@docs stringColumn, intColumn, floatColumn
@docs customColumn, veryCustomColumn


# Defaults

@docs noFiltering, noSorting


# View

@docs view

-}

import Array exposing (Array)
import Compare exposing (Comparator)
import DataView.Options exposing (Options, PaginationOption(..), SelectingOption(..), SortingOption(..))
import Html exposing (Attribute, Html, button, div, input, span, text)
import Html.Attributes as Attributes exposing (class, type_)
import Html.Events exposing (on, onClick)
import Html.Keyed as Keyed
import Html.Lazy as Lazy exposing (lazy4)
import Json.Decode as D
import List.Extra
import UI.Table as Table exposing (td, th, tr)



-- MODEL


{-| Tracks which column to sort by.
-}
type alias Model =
    { key : String
    , options : Options
    , sorting : List Sorting
    , filters : List Filter
    , selections : List Int
    , page : Int
    }


type alias Sorting =
    ( String, Direction )


type alias Filter =
    ( String, String )


type Direction
    = Ascending
    | Descending
    | None


{-| Create a table state. By providing a column name, you determine which
column should be used for sorting by default. So if you want your table of
yachts to be sorted by length by default, you might say:

    import Table

    Table.init "Length"

-}
init : String -> Options -> Model
init key options =
    { key = key
    , options = options
    , sorting = []
    , filters = []
    , selections = []
    , page = 1
    }



-- UPDATE


type Msg
    = Sort String
    | Filter String String
    | NextPage
    | PrevPage
    | SetPage Int
    | ToggleSelection Int
    | ToggleSelectAll Int


update : Msg -> Model -> Model
update msg model =
    case msg of
        Sort key ->
            let
                direction =
                    findSorting key model.sorting |> stepDirection

                sorting =
                    case direction of
                        None ->
                            List.filter (\s -> Tuple.first s /= key) model.sorting

                        _ ->
                            let
                                newSorting =
                                    List.filter (\s -> Tuple.first s /= key) model.sorting
                            in
                            List.append newSorting [ ( key, direction ) ]
            in
            { model | sorting = sorting }

        Filter key s ->
            let
                filters =
                    case s of
                        "" ->
                            List.filter (\f -> Tuple.first f /= key) model.filters

                        _ ->
                            let
                                newFilters =
                                    List.filter (\f -> Tuple.first f /= key) model.filters
                            in
                            List.append newFilters [ ( key, s ) ]
            in
            { model | filters = filters }

        NextPage ->
            { model | page = model.page + 1 }

        PrevPage ->
            { model | page = max 1 (model.page - 1) }

        SetPage page ->
            { model | page = page }

        ToggleSelection index ->
            if listContains index model.selections then
                { model | selections = List.filter (\i -> i /= index) model.selections }

            else
                { model | selections = index :: model.selections }

        ToggleSelectAll dataLength ->
            if dataLength == List.length model.selections then
                { model | selections = [] }

            else
                { model | selections = List.range 0 <| dataLength - 1 }


stepDirection : Direction -> Direction
stepDirection direction =
    case direction of
        Ascending ->
            Descending

        Descending ->
            None

        None ->
            Ascending


findSorting : String -> List Sorting -> Direction
findSorting key sorting =
    case List.Extra.find (\s -> Tuple.first s == key) sorting of
        Just s ->
            Tuple.second s

        Nothing ->
            None


listContains : a -> List a -> Bool
listContains item list =
    case List.head <| List.filter (\i -> i == item) list of
        Just found ->
            True

        Nothing ->
            False


onToggleCheck : msg -> Attribute msg
onToggleCheck msg =
    on "input" <| D.succeed msg


findColumn : String -> List (Column data msg) -> Maybe (Column data msg)
findColumn key columns =
    List.head <| List.filter (\c -> c.name == key) columns



-- CONFIG


{-| Configuration for your table, describing your columns.

**Note:** Your `Config` should _never_ be held in your model.
It should only appear in `view` code.

-}
type alias Config data msg =
    { toId : data -> String
    , toMsg : Msg -> msg
    , columns : List (Column data msg)
    }



-- COLUMNS


{-| Describes how to turn `data` into a column in your table.
-}
type alias Column data msg =
    { name : String
    , view : data -> Html msg
    , sorter : Comparator data
    , filter : data -> String -> Bool
    }


{-| -}
stringColumn : { label : String, getter : data -> String } -> Column data msg
stringColumn { label, getter } =
    { name = label
    , view = getter >> Lazy.lazy text
    , sorter = Compare.by getter
    , filter = getter >> String.startsWith
    }


{-| -}
intColumn : { label : String, getter : data -> Int } -> Column data msg
intColumn { label, getter } =
    { name = label
    , view = getter >> String.fromInt >> Lazy.lazy text
    , sorter = Compare.by getter
    , filter = getter >> String.fromInt >> String.startsWith
    }


{-| -}
floatColumn : { label : String, getter : data -> Float } -> Column data msg
floatColumn { label, getter } =
    { name = label
    , view = getter >> String.fromFloat >> Lazy.lazy text
    , sorter = Compare.by getter
    , filter = getter >> String.fromFloat >> String.startsWith
    }


{-| -}
customColumn :
    { label : String
    , getter : data -> String
    , sorter : Comparator data
    }
    -> Column data msg
customColumn { label, getter, sorter } =
    { name = label
    , view = getter >> Lazy.lazy text
    , sorter = sorter
    , filter = getter >> String.startsWith
    }


{-| -}
veryCustomColumn :
    { label : String
    , getter : data -> Html msg
    , sorter : data -> data -> Order
    }
    -> Column data msg
veryCustomColumn { label, getter, sorter } =
    { name = label
    , view = getter
    , sorter = sorter
    , filter = \_ _ -> True -- Custom views may not support text-based filtering
    }



-- FILTER, SORTING, PAGINATION


{-| フィルタリング処理を関数として分離
-}
applyFilters : List Filter -> List (Column data msg) -> Array data -> List Int -> List Int
applyFilters filters columns dataArray indexes =
    List.foldl
        (\f data ->
            case findColumn (Tuple.first f) columns of
                Just c ->
                    List.filter
                        (\d ->
                            case Array.get d dataArray of
                                Just r ->
                                    c.filter r <| Tuple.second f

                                Nothing ->
                                    False
                        )
                        data

                Nothing ->
                    data
        )
        indexes
        filters


{-| ソート処理を関数として分離
-}
applySorting : List Sorting -> List (Column data msg) -> Array data -> List Int -> List Int
applySorting sortings columns dataArray indexes =
    List.foldl
        (\s data ->
            let
                dir =
                    Tuple.second s
            in
            case findColumn (Tuple.first s) columns of
                Just c ->
                    List.sortWith (sorter_ (inDirection dir c.sorter) dataArray) data

                Nothing ->
                    data
        )
        indexes
        sortings


{-| Descending sorts the comparator backwards rather than reversing the sorted
list. Reversing the list would also undo the order of the rows the comparator
called equal, so a second click on a column would shuffle ties instead of
leaving them as they came in.
-}
inDirection : Direction -> Comparator data -> Comparator data
inDirection direction comparator =
    case direction of
        Descending ->
            Compare.reverse comparator

        _ ->
            comparator


sorter_ : Comparator data -> Array data -> Int -> Int -> Order
sorter_ sortFn data a b =
    case ( Array.get a data, Array.get b data ) of
        ( Just ra, Just rb ) ->
            sortFn ra rb

        ( Just _, Nothing ) ->
            GT

        ( Nothing, Just _ ) ->
            LT

        ( Nothing, Nothing ) ->
            EQ


applyPagination : PaginationOption -> Int -> List Int -> List Int
applyPagination option page indexes =
    case option of
        Pagination pageSize ->
            List.drop (pageSize * (page - 1)) indexes
                |> List.take pageSize

        NoPagination ->
            indexes



-- VIEW


{-| Render table.
-}
view : Config data msg -> Model -> List data -> Html msg
view ({ columns } as config) model dataList =
    let
        dataArray =
            Array.fromList dataList

        displayIndexes =
            List.range 0 (Array.length dataArray - 1)
                |> applyFilters model.filters columns dataArray
                |> applySorting model.sorting columns dataArray

        totalPages =
            calculatePageCount model.options.pagination (List.length displayIndexes)
    in
    div []
        [ table config model dataArray displayIndexes
        , pagination config.toMsg model.page totalPages
        ]


table : Config data msg -> Model -> Array data -> List Int -> Html msg
table config model dataArray displayIndexes =
    Table.table
        [ class "table table-sm" ]
        [ thead config model dataArray
        , Keyed.node "tbody" [] <|
            viewBodyRows config model displayIndexes dataArray
        ]


thead : Config data msg -> Model -> Array data -> Html msg
thead { toMsg, columns } model data =
    let
        allSelected =
            Array.length data == List.length model.selections

        selectionCell =
            case model.options.selecting of
                Selecting ->
                    [ th []
                        [ input
                            [ type_ "checkbox"
                            , onToggleCheck <| toMsg <| ToggleSelectAll (Array.length data)
                            , Attributes.checked allSelected
                            ]
                            []
                        ]
                    ]

                NoSelecting ->
                    []
    in
    Table.thead []
        [ tr [] <|
            List.concat
                [ selectionCell
                , List.map (theadCell toMsg model) columns
                ]
        ]


theadCell : (Msg -> msg) -> Model -> Column data msg -> Html msg
theadCell toMsg model c =
    th
        (case model.options.sorting of
            Sorting ->
                [ onClick <| toMsg <| Sort c.name
                , class "select-none"
                ]

            NoSorting ->
                []
        )
        [ text <| c.name
        , sortIndicator (findSorting c.name model.sorting)
        ]


sortIndicator : Direction -> Html msg
sortIndicator direction =
    case direction of
        Ascending ->
            darkGrey "↑"

        Descending ->
            darkGrey "↓"

        None ->
            lightGrey "↕"


darkGrey : String -> Html msg
darkGrey symbol =
    span [ class "text-[#555]" ] [ text symbol ]


lightGrey : String -> Html msg
lightGrey symbol =
    span [ class "text-[#ccc]" ] [ text symbol ]


viewBodyRows : Config data msg -> Model -> List Int -> Array data -> List ( String, Html msg )
viewBodyRows config model indexes data =
    let
        window =
            indexes
                |> applyPagination model.options.pagination model.page

        rows =
            window
                |> List.filterMap (\i -> Array.get i data)
    in
    List.map2 (tableRow config model) window rows


tableRow : Config data msg -> Model -> Int -> data -> ( String, Html msg )
tableRow config model index data =
    ( config.toId data
    , lazy4 tableRowHelp config model index data
    )


tableRowHelp : Config data msg -> Model -> Int -> data -> Html msg
tableRowHelp { toMsg, columns } model index data =
    let
        selectionCell =
            case model.options.selecting of
                Selecting ->
                    [ td []
                        [ input
                            [ type_ "checkbox"
                            , onToggleCheck <| toMsg <| ToggleSelection index
                            , Attributes.checked <| listContains index model.selections
                            ]
                            []
                        ]
                    ]

                NoSelecting ->
                    []
    in
    tr [] <|
        List.concat
            [ selectionCell
            , List.map (\c -> td [] [ c.view data ]) columns
            ]


calculatePageCount : PaginationOption -> Int -> Int
calculatePageCount option totalItems =
    case option of
        Pagination pageSize ->
            if modBy pageSize totalItems == 0 then
                totalItems // pageSize

            else
                (totalItems // pageSize) + 1

        NoPagination ->
            0


pagination : (Msg -> msg) -> Int -> Int -> Html msg
pagination toMsg currentPage totalPages =
    div
        [ class "flex justify-end pt-2" ]
        (List.map (paginationButton toMsg currentPage) (List.range 0 (totalPages - 1)))


paginationButton : (Msg -> msg) -> Int -> Int -> Html msg
paginationButton toMsg activePage n =
    let
        page =
            n + 1
    in
    button
        [ class
            ("border border-[#63B3ED] bg-white text-black rounded-[2px] inline m-[0.1rem] py-1 px-2 hover:cursor-pointer"
                ++ (if page == activePage then
                        " bg-[#63B3ED] text-white"

                    else
                        ""
                   )
            )
        , onClick <| toMsg <| SetPage page
        ]
        [ text <| String.fromInt page ]


{-| No-op function for disabled sorting. This will go away one day.
-}
noSorting : a -> String
noSorting _ =
    ""


{-| No-op function for diabled filtering. This will also go away one day.
-}
noFiltering : a -> String -> Bool
noFiltering _ _ =
    True
