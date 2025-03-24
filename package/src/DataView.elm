module DataView exposing
    ( Filter, Model, Msg(..), Sorting, Config
    , Column, stringColumn, intColumn, floatColumn
    , noFiltering, noSorting
    , init
    , update
    , view
    )

{-| A datatable.

See an example of this library in action [here](https://gitlab.com/docmenthol/autotable/-/blob/master/examples/basic/src/Main.elm).


# Types

@docs Filter, Model, Msg, Sorting, Config

@docs Column, stringColumn, intColumn, floatColumn


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
import DataView.Options exposing (Options, PaginationOption(..), SelectingOption(..), SortingOption(..))
import Html.Styled exposing (Attribute, Html, a, button, div, input, span, tbody, td, text, th, thead, tr)
import Html.Styled.Attributes exposing (checked, class, style, type_)
import Html.Styled.Events exposing (on, onClick)
import Html.Styled.Keyed as Keyed
import Html.Styled.Lazy exposing (lazy2)
import Json.Decode as D
import List.Extra
import Motorsport.Utils exposing (compareBy)



-- MODEL


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
                    findSorting model.sorting key |> stepDirection

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


findSorting : List Sorting -> String -> Direction
findSorting sorting key =
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


findColumn : List (Column data msg) -> String -> Maybe (Column data msg)
findColumn columns key =
    List.head <| List.filter (\c -> c.name == key) columns


setOrder : Direction -> List a -> List a
setOrder direction data =
    case direction of
        Descending ->
            List.reverse data

        _ ->
            data



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


{-| Define a table column.
-}
type alias Column data msg =
    { name : String
    , view : data -> Html msg
    , sorter : data -> data -> Order
    , filter : data -> String -> Bool
    }


{-| -}
stringColumn : { label : String, getter : data -> String } -> Column data msg
stringColumn { label, getter } =
    { name = label
    , view = getter >> text
    , sorter = compareBy getter
    , filter = getter >> String.startsWith
    }


{-| -}
intColumn : { label : String, getter : data -> Int } -> Column data msg
intColumn { label, getter } =
    { name = label
    , view = getter >> String.fromInt >> text
    , sorter = compareBy getter
    , filter = getter >> String.fromInt >> String.startsWith
    }


{-| -}
floatColumn : { label : String, getter : data -> Float } -> Column data msg
floatColumn { label, getter } =
    { name = label
    , view = getter >> String.fromFloat >> text
    , sorter = compareBy getter
    , filter = getter >> String.fromFloat >> String.startsWith
    }


sorter : (data -> data -> Order) -> Array data -> Int -> Int -> Order
sorter sortFn data a b =
    case ( Array.get a data, Array.get b data ) of
        ( Just ra, Just rb ) ->
            sortFn ra rb

        ( Just _, Nothing ) ->
            GT

        ( Nothing, Just _ ) ->
            LT

        ( Nothing, Nothing ) ->
            EQ



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
    in
    div []
        [ table config model dataArray displayIndexes
        , pagination config.toMsg model displayIndexes
        ]


table : Config data msg -> Model -> Array data -> List Int -> Html msg
table config model dataArray displayIndexes =
    Html.Styled.table
        [ class <| "autotable autotable-" ++ model.key ]
        [ thead [] [ tr [] <| viewHeaderCells config model dataArray ]
        , Keyed.node "tbody" [] <|
            viewBodyRows config model displayIndexes dataArray
        ]


viewHeaderCells : Config data msg -> Model -> Array data -> List (Html msg)
viewHeaderCells { toMsg, columns } model data =
    let
        allSelected =
            Array.length data == List.length model.selections
    in
    List.concat
        [ case model.options.selecting of
            Selecting ->
                [ th
                    [ style "width" "1%", class "autotable__checkbox-header" ]
                    [ input [ type_ "checkbox", onToggleCheck <| toMsg <| ToggleSelectAll (Array.length data), checked allSelected ] [] ]
                ]

            NoSelecting ->
                []
        , List.map (headerCell toMsg model) columns
        ]


headerCell : (Msg -> msg) -> Model -> Column data msg -> Html msg
headerCell toMsg model c =
    let
        sorting =
            findSorting model.sorting c.name |> viewDirection
    in
    th (headerCellAttrs toMsg model c)
        [ text <| c.name
        , span [ class "autotable__sort-indicator" ] [ text sorting ]
        ]


headerCellAttrs : (Msg -> msg) -> Model -> Column data msg -> List (Attribute msg)
headerCellAttrs toMsg { options } c =
    List.concat
        [ case options.sorting of
            Sorting ->
                [ onClick <| toMsg <| Sort c.name
                , style "user-select" "none"
                ]

            NoSorting ->
                []
        , [ class <| "autotable__Column a msgutotable__column-" ++ c.name ]
        ]


viewDirection : Direction -> String
viewDirection direction =
    case direction of
        Ascending ->
            "▲"

        Descending ->
            "▼"

        None ->
            ""


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
tableRow { toId, toMsg, columns } model index row =
    ( toId row
    , tr [] <|
        List.concat
            [ case model.options.selecting of
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
            , List.map (\c -> lazy2 tableData c row) columns
            ]
    )


tableData : Column data msg -> data -> Html msg
tableData column row =
    td [ class "text-left" ] [ column.view row ]


pagination : (Msg -> msg) -> Model -> List Int -> Html msg
pagination toMsg model displayIndexes =
    let
        length =
            List.length displayIndexes

        numPages =
            case model.options.pagination of
                Pagination pageSize ->
                    if modBy pageSize length == 0 then
                        length // pageSize

                    else
                        (length // pageSize) + 1

                NoPagination ->
                    0
    in
    div [ class "autotable__pagination" ]
        (paginationButton toMsg model.page
            |> Array.initialize numPages
            |> Array.toList
        )


paginationButton : (Msg -> msg) -> Int -> Int -> Html msg
paginationButton toMsg activePage n =
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


{-| フィルタリング処理を関数として分離
-}
applyFilters : List Filter -> List (Column data msg) -> Array data -> List Int -> List Int
applyFilters filters columns dataArray indexes =
    List.foldl
        (\f data ->
            case findColumn columns (Tuple.first f) of
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
            case findColumn columns (Tuple.first s) of
                Just c ->
                    setOrder dir <| List.sortWith (sorter c.sorter dataArray) data

                Nothing ->
                    data
        )
        indexes
        sortings


applyPagination : PaginationOption -> Int -> List Int -> List Int
applyPagination option page indexes =
    case option of
        Pagination pageSize ->
            List.drop (pageSize * (page - 1)) indexes
                |> List.take pageSize

        NoPagination ->
            indexes
