module Motorsport.Leaderboard exposing
    ( list, table
    , stringColumn, intColumn, floatColumn
    , Model, initialSort
    , Msg, update
    , customColumn, veryCustomColumn
    , timeColumn, histogramColumn, performanceColumn
    , Config, Leaderboard, LeaderboardItem, gap_, init
    )

{-| This library helps you create sortable tables. The crucial feature is that it
lets you own your data separately and keep it in whatever format is best for
you. This way you are free to change your data without worrying about the table
&ldquo;getting out of sync&rdquo; with the data. Having a single source of
truth is pretty great!

I recommend checking out the [examples] to get a feel for how it works.

[examples]: https://github.com/evancz/elm-sortable-table/tree/master/examples


# View

@docs list, table


# Configuration

@docs stringColumn, intColumn, floatColumn


# Model

@docs Model, initialSort


# Update

@docs Msg, update


## Custom Columns

@docs Column, customColumn, veryCustomColumn

@docs timeColumn, histogramColumn, performanceColumn

-}

import Chart.Fragments exposing (dot, path)
import Css exposing (color, fontSize, hex, px)
import Html.Styled as Html exposing (Attribute, Html, li, span, text, ul)
import Html.Styled.Attributes exposing (css)
import Html.Styled.Events exposing (onClick)
import Html.Styled.Keyed as Keyed
import Html.Styled.Lazy exposing (lazy2)
import List.Extra
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Car exposing (Car)
import Motorsport.Clock exposing (Clock)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap(..))
import Motorsport.Lap as Lap exposing (Lap, completedLapsAt, findLastLapAt)
import Motorsport.LapStatus exposing (LapStatus(..), lapStatus)
import Scale exposing (ContinuousScale)
import Svg.Styled exposing (Svg, g, rect, svg)
import Svg.Styled.Attributes as SvgAttributes exposing (fill)
import TypedSvg.Styled.Attributes exposing (viewBox)
import TypedSvg.Styled.Attributes.InPx as InPx
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

    Table.initialSort "Length"

-}
initialSort : String -> Model
initialSort header =
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


timeColumn :
    { label : String
    , getter : data -> { a | time : Duration, best : Duration }
    , sorter : List data -> List data
    , analysis : Analysis
    }
    -> Column data msg
timeColumn { label, getter, sorter, analysis } =
    { name = label
    , view =
        getter
            >> (\item ->
                    span
                        [ css
                            [ color <|
                                hex <|
                                    case lapStatus { time = analysis.fastestLapTime } item of
                                        Fastest ->
                                            "#F0F"

                                        PersonalBest ->
                                            "#0C0"

                                        Normal ->
                                            "inherit"
                            ]
                        ]
                        [ text <| Duration.toString item.time ]
               )
    , sorter = sorter
    }


histogramColumn :
    { getter : data -> List Lap
    , sorter : List data -> List data
    , analysis : Analysis
    , coefficient : Float
    }
    -> Column data msg
histogramColumn { getter, sorter, analysis, coefficient } =
    { name = "Histogram"
    , view = getter >> histogram analysis coefficient
    , sorter = sorter
    }


performanceColumn :
    { getter : data -> List Lap
    , sorter : List data -> List data
    , raceClock : Clock
    , analysis : Analysis
    , coefficient : Float
    }
    -> Column data msg
performanceColumn { getter, sorter, raceClock, analysis, coefficient } =
    { name = "Performance"
    , view = getter >> performance raceClock analysis coefficient
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


list : Config data msg -> Model -> (data -> List (Html msg)) -> List data -> Html msg
list { columns } state toListItem data =
    let
        sortedData =
            sort state columns data

        listItem d =
            li [] (toListItem d)
    in
    ul [] <| List.map listItem sortedData


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
    , lazy2 tr [] <| List.map (\{ view } -> td [] [ view data ]) columns
    )



-- PREVIOUS LEADERBOARD


type alias Leaderboard =
    List LeaderboardItem


type alias LeaderboardItem =
    { position : Int
    , carNumber : String
    , driver : String
    , lap : Int
    , gap : Gap
    , time : Duration
    , best : Duration
    , history : List Lap
    }


init : Clock -> List Car -> Leaderboard
init raceClock cars =
    let
        sortedCars =
            sortCarsAt raceClock cars
    in
    sortedCars
        |> List.indexedMap
            (\index { car, lastLap } ->
                { position = index + 1
                , driver = car.driverName
                , carNumber = car.carNumber
                , lap = lastLap.lap
                , gap =
                    List.head sortedCars
                        |> Maybe.map (\leader -> Gap.from leader.lastLap lastLap)
                        |> Maybe.withDefault Gap.None
                , time = lastLap.time
                , best = lastLap.best
                , history = completedLapsAt raceClock car.laps
                }
            )


sortCarsAt : Clock -> List Car -> List { car : Car, lastLap : Lap }
sortCarsAt raceClock cars =
    cars
        |> List.map
            (\car ->
                let
                    lastLap =
                        findLastLapAt raceClock car.laps
                            |> Maybe.withDefault { carNumber = "", driver = "", lap = 0, time = 0, best = 0, elapsed = 0 }
                in
                { car = car, lastLap = lastLap }
            )
        |> List.sortWith (\a b -> Lap.compare a.lastLap b.lastLap)



-- VIEW


w : Float
w =
    200


h : Float
h =
    20


padding : Float
padding =
    1


xScale : ( Int, Float ) -> ContinuousScale Float
xScale ( min, max ) =
    ( toFloat min, max ) |> Scale.linear ( padding, w - padding )


yScale : ( Float, Float ) -> ContinuousScale Float
yScale ( min, max ) =
    ( min, max ) |> Scale.linear ( h - padding, padding )


histogram : Analysis -> Float -> List Lap -> Html msg
histogram { fastestLapTime, slowestLapTime } coefficient laps =
    let
        xScale_ =
            xScale ( fastestLapTime, min (toFloat fastestLapTime * coefficient) (toFloat slowestLapTime) )

        width lap =
            if isCurrentLap lap then
                3

            else
                1

        color lap =
            case
                ( isCurrentLap lap, lapStatus { time = fastestLapTime } { time = lap.time, best = lap.best } )
            of
                ( True, Fastest ) ->
                    "#F0F"

                ( True, PersonalBest ) ->
                    "#0C0"

                ( True, Normal ) ->
                    "#FC0"

                ( False, _ ) ->
                    "hsla(0, 0%, 50%, 0.5)"

        isCurrentLap { lap } =
            List.length laps == lap
    in
    svg [ viewBox 0 0 w h, SvgAttributes.css [ Css.width (px 200) ] ]
        [ histogram_
            { x = .time >> toFloat >> Scale.convert xScale_
            , y = always 0 >> Scale.convert (yScale ( 0, 0 ))
            , width = width
            , color = color
            }
            laps
        ]


histogram_ :
    { x : a -> Float, y : a -> Float, width : a -> Float, color : a -> String }
    -> List a
    -> Svg msg
histogram_ { x, y, width, color } laps =
    g [] <|
        List.map
            (\lap ->
                rect
                    [ InPx.x (x lap - 1)
                    , InPx.y (y lap - 10)
                    , InPx.width (width lap)
                    , InPx.height 20
                    , fill (color lap)
                    ]
                    []
            )
            laps


gap_ : Duration -> Html msg
gap_ time =
    svg [ viewBox 0 0 w h, SvgAttributes.css [ Css.width (px 200) ] ]
        [ rect
            [ InPx.x 0
            , InPx.y 0
            , InPx.width (time |> toFloat |> Scale.convert (xScale ( 0, 100000 )))
            , InPx.height 20
            , fill "#999"
            ]
            []
        ]


performance : Clock -> { a | fastestLapTime : Duration } -> Float -> List Lap -> Html msg
performance raceClock { fastestLapTime } coefficient laps =
    svg [ viewBox 0 0 w h, SvgAttributes.css [ Css.width (px 200) ] ]
        [ dotHistory
            { x = .elapsed >> toFloat >> Scale.convert (xScale ( 0, toFloat <| raceClock.elapsed ))
            , y = .time >> toFloat >> Scale.convert (yScale ( toFloat fastestLapTime * coefficient, toFloat fastestLapTime ))
            , color = "#999"
            }
            laps
        ]


dotHistory : { x : a -> Float, y : a -> Float, color : String } -> List a -> Svg msg
dotHistory { x, y, color } laps =
    dotHistory_
        { dots =
            List.map
                (\lap ->
                    dot
                        { cx = x lap
                        , cy = y lap
                        , fillColor = color
                        }
                )
                laps
        , path =
            laps
                |> List.map (\item -> Just ( x item, y item ))
                |> path { strokeColor = color }
        }


dotHistory_ : { dots : List (Svg msg), path : Svg msg } -> Svg msg
dotHistory_ options =
    g []
        [ options.path
        , g [] options.dots
        ]
