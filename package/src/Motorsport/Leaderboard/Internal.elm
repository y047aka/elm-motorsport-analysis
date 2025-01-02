module Motorsport.Leaderboard.Internal exposing
    ( Model, init
    , Msg, update
    , Config, Column
    , stringColumn, intColumn, floatColumn
    , customColumn, veryCustomColumn
    , table
    )

{-| This library helps you create sortable tables. The crucial feature is that it
lets you own your data separately and keep it in whatever format is best for
you. This way you are free to change your data without worrying about the table
&ldquo;getting out of sync&rdquo; with the data. Having a single source of
truth is pretty great!

I recommend checking out the [examples] to get a feel for how it works.

[examples]: https://github.com/evancz/elm-sortable-table/tree/master/examples


# Model

@docs Model, init


# Update

@docs Msg, update


# Configuration

@docs Config, Column
@docs stringColumn, intColumn, floatColumn
@docs customColumn, veryCustomColumn


# View

@docs list, table

-}

import Css exposing (color, fontSize, hex, px)
import Html.Styled exposing (Attribute, Html, span, text)
import Html.Styled.Attributes exposing (css)
import Html.Styled.Events exposing (onClick)
import Html.Styled.Keyed as Keyed
import Html.Styled.Lazy exposing (lazy2)
import List.Extra
import UI.Table as Table exposing (td, th, thead, tr)



-- MODEL


{-| Tracks which column to sort by.
-}
type alias Model =
    { sorting : List Sorting }


type alias Sorting =
    ( String, Direction )


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
init : String -> Model
init header =
    { sorting = [] }



-- UPDATE


type Msg
    = Sort String


update : Msg -> Model -> Model
update msg model =
    case msg of
        Sort key ->
            let
                newDirection =
                    findSorting key model.sorting |> stepDirection

                sorting =
                    case newDirection of
                        None ->
                            List.filter (\s -> Tuple.first s /= key) model.sorting

                        _ ->
                            let
                                newSorting =
                                    List.filter (\s -> Tuple.first s /= key) model.sorting
                            in
                            List.append newSorting [ ( key, newDirection ) ]
            in
            { model | sorting = sorting }


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
    List.Extra.find (\( key_, _ ) -> key_ == key) sorting
        |> Maybe.map (\( _, direction ) -> direction)
        |> Maybe.withDefault None



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
    , sorter : List data -> List data
    }


{-| -}
stringColumn : { label : String, getter : data -> String } -> Column data msg
stringColumn { label, getter } =
    { name = label
    , view = getter >> text
    , sorter = List.sortBy getter
    }


{-| -}
intColumn : { label : String, getter : data -> Int } -> Column data msg
intColumn { label, getter } =
    { name = label
    , view = getter >> String.fromInt >> text
    , sorter = List.sortBy getter
    }


{-| -}
floatColumn : { label : String, getter : data -> Float } -> Column data msg
floatColumn { label, getter } =
    { name = label
    , view = getter >> String.fromFloat >> text
    , sorter = List.sortBy getter
    }


{-| -}
customColumn :
    { label : String
    , getter : data -> String
    , sorter : List data -> List data
    }
    -> Column data msg
customColumn { label, getter, sorter } =
    { name = label
    , view = getter >> text
    , sorter = sorter
    }


{-| -}
veryCustomColumn :
    { label : String
    , getter : data -> Html msg
    , sorter : List data -> List data
    }
    -> Column data msg
veryCustomColumn { label, getter, sorter } =
    { name = label
    , view = getter
    , sorter = sorter
    }



-- SORTING


sort : Model -> List (Column data msg) -> List data -> List data
sort { sorting } columns prevData =
    List.foldl
        (\( key, direction ) data ->
            findSorter key columns
                |> Maybe.map (\sorter -> applySorter direction sorter data)
                |> Maybe.withDefault data
        )
        prevData
        sorting


findSorter : String -> List (Column data msg) -> Maybe (List data -> List data)
findSorter key columns =
    columns
        |> List.Extra.find (\c -> c.name == key)
        |> Maybe.map .sorter


applySorter : Direction -> (List data -> List data) -> List data -> List data
applySorter direction sorter data =
    case direction of
        Descending ->
            sorter data
                |> List.reverse

        _ ->
            sorter data



-- VIEW


table : Config data msg -> Model -> List data -> Html msg
table { toId, toMsg, columns } state data =
    let
        sortedData =
            sort state columns data
    in
    Table.table [ css [ fontSize (px 14) ] ]
        [ thead []
            [ tr [] <|
                List.map (toHeaderInfo state.sorting toMsg >> simpleTheadHelp) columns
            ]
        , Keyed.node "tbody" [] <|
            List.map (tableRow toId columns) sortedData
        ]


toHeaderInfo : List Sorting -> (Msg -> msg) -> Column data msg -> ( String, Direction, Attribute msg )
toHeaderInfo sortings toMsg { name } =
    ( name
    , findSorting name sortings
    , onClick <| toMsg <| Sort name
    )


simpleTheadHelp : ( String, Direction, Attribute msg ) -> Html msg
simpleTheadHelp ( name, direction, onClick_ ) =
    let
        symbol =
            case direction of
                Ascending ->
                    darkGrey "↑"

                Descending ->
                    darkGrey "↓"

                None ->
                    lightGrey "↕"

        content =
            [ text (name ++ " "), symbol ]
    in
    th [ onClick_ ] content


darkGrey : String -> Html msg
darkGrey symbol =
    span [ css [ color (hex "#555") ] ] [ text symbol ]


lightGrey : String -> Html msg
lightGrey symbol =
    span [ css [ color (hex "#ccc") ] ] [ text symbol ]


tableRow : (data -> String) -> List (Column data msg) -> data -> ( String, Html msg )
tableRow toId columns data =
    ( toId data
    , lazy2 tr [] <| List.map (\column -> td [] [ column.view data ]) columns
    )
