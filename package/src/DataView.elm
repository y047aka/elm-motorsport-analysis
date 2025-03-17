module DataView exposing
    ( Column, Filter, Model, Msg(..), Sorting
    , noFiltering, noSorting
    , init
    , update
    , view
    )

{-| A datatable.

See an example of this library in action [here](https://gitlab.com/docmenthol/autotable/-/blob/master/examples/basic/src/Main.elm).


# Types

@docs Column, Filter, Model, Msg, Sorting


# Defaults

@docs noFiltering, noSorting


# Init

@docs init


# Update

@docs update


# View

@docs view

-}

import Array exposing (Array)
import DataView.Options exposing (..)
import Html.Styled exposing (Attribute, Html, a, button, div, input, span, table, tbody, td, text, th, thead, tr)
import Html.Styled.Attributes exposing (checked, class, style, type_)
import Html.Styled.Events exposing (on, onClick)
import Json.Decode as D
import Tuple exposing (first, second)


type Direction
    = Asc
    | Desc
    | None


{-| Represents a sorting direction.
-}
type alias Sorting =
    ( String, Direction )


{-| Represents a filter.
-}
type alias Filter =
    ( String, String )


{-| Define a table column.
-}
type alias Column a =
    { label : String
    , key : String
    , render : a -> String
    , sort : a -> String
    , filter : a -> String -> Bool
    }


{-| Table state.
-}
type alias Model a =
    { columns : List (Column a)
    , data : Array a
    , sorting : List Sorting
    , filters : List Filter
    , selections : List Int
    , page : Int
    , options : Options
    , key : String
    }


{-| Table signals.
-}
type Msg
    = Sort String
    | Filter String String
    | NextPage
    | PrevPage
    | SetPage Int
    | ToggleSelection Int
    | ToggleSelectAll


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


stepDirection : Direction -> Direction
stepDirection direction =
    case direction of
        Asc ->
            Desc

        Desc ->
            None

        None ->
            Asc


findColumn : List (Column a) -> String -> Maybe (Column a)
findColumn columns key =
    List.head <| List.filter (\c -> c.key == key) columns


findSorting : List Sorting -> String -> Direction
findSorting sorting key =
    case List.head <| List.filter (\s -> first s == key) sorting of
        Just s ->
            second s

        Nothing ->
            None


setOrder : Direction -> List a -> List a
setOrder direction data =
    case direction of
        Desc ->
            List.reverse data

        _ ->
            data


{-| Create table state.
-}
init : String -> List (Column a) -> List a -> Options -> Model a
init key columns data options =
    { columns = columns
    , data = Array.fromList data
    , sorting = []
    , filters = []
    , selections = []
    , page = 1
    , options = options
    , key = key
    }


{-| Update table state.
-}
update : Msg -> Model a -> Model a
update msg model =
    case msg of
        Sort key ->
            let
                dir =
                    findSorting model.sorting key |> stepDirection

                sorting =
                    case dir of
                        None ->
                            List.filter (\s -> first s /= key) model.sorting

                        _ ->
                            let
                                newSorting =
                                    List.filter (\s -> first s /= key) model.sorting
                            in
                            List.append newSorting [ ( key, dir ) ]
            in
            { model | sorting = sorting }

        Filter key s ->
            let
                filters =
                    case s of
                        "" ->
                            List.filter (\f -> first f /= key) model.filters

                        _ ->
                            let
                                newFilters =
                                    List.filter (\f -> first f /= key) model.filters
                            in
                            List.append newFilters [ ( key, s ) ]
            in
            { model | filters = filters }

        NextPage ->
            { model | page = model.page + 1 }

        PrevPage ->
            let
                page =
                    max 1 <| model.page - 1
            in
            { model | page = page }

        SetPage page ->
            { model | page = page }

        ToggleSelection index ->
            if listContains index model.selections then
                { model | selections = List.filter (\i -> i /= index) model.selections }

            else
                { model | selections = index :: model.selections }

        ToggleSelectAll ->
            if Array.length model.data == List.length model.selections then
                { model | selections = [] }

            else
                { model | selections = List.range 0 <| Array.length model.data - 1 }


sorter : (a -> String) -> Array a -> Int -> Int -> Order
sorter sortFn data a b =
    let
        ca =
            case Array.get a data of
                Just r ->
                    sortFn r

                Nothing ->
                    ""

        cb =
            case Array.get b data of
                Just r ->
                    sortFn r

                Nothing ->
                    ""
    in
    compare ca cb


{-| Render table.
-}
view : Model a -> (Msg -> msg) -> Html msg
view model toMsg =
    let
        indexes =
            List.range 0 <| Array.length model.data - 1

        filteredIndexes =
            List.foldl
                (\f data ->
                    case findColumn model.columns (first f) of
                        Just c ->
                            List.filter
                                (\d ->
                                    case Array.get d model.data of
                                        Just r ->
                                            c.filter r <| second f

                                        Nothing ->
                                            False
                                )
                                data

                        Nothing ->
                            data
                )
                indexes
                model.filters

        sortedIndexes =
            List.foldl
                (\s data ->
                    let
                        dir =
                            second s
                    in
                    case findColumn model.columns (first s) of
                        Just c ->
                            setOrder dir <| List.sortWith (sorter c.sort model.data) data

                        Nothing ->
                            data
                )
                filteredIndexes
                model.sorting
    in
    div []
        [ table
            [ class <| "autotable autotable-" ++ model.key ]
            [ thead [] [ tr [] <| viewHeaderCells model toMsg ]
            , tbody [] <| viewBodyRows model sortedIndexes toMsg
            ]
        , viewPagination model filteredIndexes toMsg
        ]


viewDirection : Direction -> String
viewDirection direction =
    case direction of
        Asc ->
            "▲"

        Desc ->
            "▼"

        None ->
            ""


headerCellAttrs : Model a -> (Msg -> msg) -> Column a -> List (Attribute msg)
headerCellAttrs model toMsg c =
    List.concat
        [ case sorting model.options of
            Sorting ->
                [ onClick <| toMsg <| Sort c.key ]

            NoSorting ->
                []
        , case sorting model.options of
            Sorting ->
                [ style "user-select" "none" ]

            _ ->
                []
        , [ class <| "autotable__column autotable__column-" ++ c.key ]
        ]


viewHeaderCells : Model a -> (Msg -> msg) -> List (Html msg)
viewHeaderCells model toMsg =
    let
        makeAttrs =
            headerCellAttrs model toMsg

        headerCells =
            List.map
                (\c ->
                    let
                        sorting =
                            findSorting model.sorting c.key |> viewDirection
                    in
                    th
                        (makeAttrs c)
                        [ text <| c.label
                        , span [ class "autotable__sort-indicator" ] [ text sorting ]
                        ]
                )
                model.columns

        allSelected =
            Array.length model.data == List.length model.selections
    in
    List.concat
        [ case selecting model.options of
            Selecting ->
                [ th
                    [ style "width" "1%", class "autotable__checkbox-header" ]
                    [ input [ type_ "checkbox", onToggleCheck <| toMsg <| ToggleSelectAll, checked allSelected ] [] ]
                ]

            NoSelecting ->
                []
        , headerCells
        ]


viewBodyRows : Model a -> List Int -> (Msg -> msg) -> List (Html msg)
viewBodyRows model indexes toMsg =
    let
        window =
            case pagination model.options of
                Pagination pageSize ->
                    List.take pageSize <| List.drop (pageSize * (model.page - 1)) indexes

                NoPagination ->
                    indexes

        rows =
            List.filterMap (\i -> Array.get i model.data) window

        buildRow index row =
            tr [] <|
                List.concat
                    [ case selecting model.options of
                        Selecting ->
                            [ td
                                [ class "autotable__checkbox" ]
                                [ input
                                    [ type_ "checkbox"
                                    , onToggleCheck <| toMsg <| ToggleSelection index
                                    , checked <| listContains index model.selections
                                    ]
                                    []
                                ]
                            ]

                        NoSelecting ->
                            []
                    , List.map (\c -> viewDisplayRow c row) model.columns
                    ]
    in
    List.map2 buildRow window rows


viewDisplayRow : Column a -> a -> Html msg
viewDisplayRow column row =
    td [ class "text-left" ] [ text <| column.render row ]


viewPaginationButton : Int -> (Msg -> msg) -> Int -> Html msg
viewPaginationButton activePage toMsg n =
    let
        page =
            n + 1

        classes =
            if page == activePage then
                "autotable__pagination-page autotable__pagination-active"

            else
                "autotable__pagination-page"
    in
    button
        [ class classes, onClick <| toMsg <| SetPage page ]
        [ text <| String.fromInt page ]


viewPagination : Model a -> List Int -> (Msg -> msg) -> Html msg
viewPagination model filteredIndexes toMsg =
    let
        length =
            List.length filteredIndexes

        numPages =
            case pagination model.options of
                Pagination pageSize ->
                    if modBy pageSize length == 0 then
                        length // pageSize

                    else
                        (length // pageSize) + 1

                NoPagination ->
                    0

        pageButtons =
            Array.toList <|
                Array.initialize numPages <|
                    viewPaginationButton model.page toMsg
    in
    div [ class "autotable__pagination" ] pageButtons


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
