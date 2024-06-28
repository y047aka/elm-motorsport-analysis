module Motorsport.Leaderboard exposing
    ( list, table
    , stringColumn, intColumn, floatColumn
    , State, initialSort
    , customColumn, veryCustomColumn
    , increasingOrDecreasingBy
    , Config, init, view_
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


# State

@docs State, initialSort


## Custom Columns

@docs Column, customColumn, veryCustomColumn
@docs increasingOrDecreasingBy

-}

import Chart.Fragments exposing (dot, path)
import Css exposing (color, fontSize, hex, px)
import Html.Styled as Html exposing (Attribute, Html, li, span, text, ul)
import Html.Styled.Attributes exposing (css)
import Html.Styled.Events as Events
import Html.Styled.Keyed as Keyed
import Html.Styled.Lazy exposing (lazy2)
import Json.Decode as Json
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



-- STATE


{-| Tracks which column to sort by.
-}
type State
    = State String Bool


{-| Create a table state. By providing a column name, you determine which
column should be used for sorting by default. So if you want your table of
yachts to be sorted by length by default, you might say:

    import Table

    Table.initialSort "Length"

-}
initialSort : String -> State
initialSort header =
    State header False



-- CONFIG


{-| Configuration for your table, describing your columns.

**Note:** Your `Config` should _never_ be held in your model.
It should only appear in `view` code.

-}
type alias Config data msg =
    { toId : data -> String
    , toMsg : State -> msg
    , columns : List (Column data msg)
    }


{-| The status of a particular column, for use in the `thead` field of your
`Customizations`.

  - If the column is unsortable, the status will always be `Unsortable`.
  - If the column can be sorted in one direction, the status will be `Sortable`.
    The associated boolean represents whether this column is selected. So it is
    `True` if the table is currently sorted by this column, and `False` otherwise.
  - If the column can be sorted in either direction, the status will be `Reversible`.
    The associated maybe tells you whether this column is selected. It is
    `Just isReversed` if the table is currently sorted by this column, and
    `Nothing` otherwise. The `isReversed` boolean lets you know which way it
    is sorted.

This information lets you do custom header decorations for each scenario.

-}
type Status
    = Unsortable
    | Sortable Bool
    | Reversible (Maybe Bool)



-- COLUMNS


{-| Describes how to turn `data` into a column in your table.
-}
type alias Column data msg =
    { name : String
    , view : data -> Html msg
    , sorter : Sorter data
    }


{-| -}
stringColumn : { label : String, getter : data -> String } -> Column data msg
stringColumn { label, getter } =
    { name = label
    , view = getter >> text
    , sorter = increasingOrDecreasingBy getter
    }


{-| -}
intColumn : { label : String, getter : data -> Int } -> Column data msg
intColumn { label, getter } =
    { name = label
    , view = getter >> String.fromInt >> text
    , sorter = increasingOrDecreasingBy getter
    }


{-| -}
floatColumn : { label : String, getter : data -> Float } -> Column data msg
floatColumn { label, getter } =
    { name = label
    , view = getter >> String.fromFloat >> text
    , sorter = increasingOrDecreasingBy getter
    }


{-| -}
customColumn :
    { label : String
    , getter : data -> String
    , sorter : Sorter data
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
    , sorter : Sorter data
    }
    -> Column data msg
veryCustomColumn { label, getter, sorter } =
    { name = label
    , view = getter
    , sorter = sorter
    }



-- SORTING


sort : State -> List (Column data msg) -> List data -> List data
sort (State selectedColumn isReversed) columns data =
    case findSorter selectedColumn columns of
        Nothing ->
            data

        Just sorter ->
            applySorter isReversed sorter data


findSorter : String -> List (Column data msg) -> Maybe (Sorter data)
findSorter selectedColumn columns =
    case columns of
        [] ->
            Nothing

        { name, sorter } :: remainingColumns ->
            if name == selectedColumn then
                Just sorter

            else
                findSorter selectedColumn remainingColumns


applySorter : Bool -> Sorter data -> List data -> List data
applySorter isReversed sorter data =
    case sorter of
        None ->
            data

        Increasing sort_ ->
            sort_ data

        Decreasing sort_ ->
            List.reverse (sort_ data)

        IncOrDec sort_ ->
            if isReversed then
                List.reverse (sort_ data)

            else
                sort_ data

        DecOrInc sort_ ->
            if isReversed then
                sort_ data

            else
                List.reverse (sort_ data)



-- SORTERS


{-| Specifies a particular way of sorting data.
-}
type Sorter data
    = None
    | Increasing (List data -> List data)
    | Decreasing (List data -> List data)
    | IncOrDec (List data -> List data)
    | DecOrInc (List data -> List data)


{-| Sometimes you want to be able to sort data in increasing _or_ decreasing
order. Maybe you have race times for the 100 meter sprint. This function lets
sort by best time by default, but also see the other order.

    sorter : Sorter { a | time : comparable }
    sorter =
        increasingOrDecreasingBy .time

-}
increasingOrDecreasingBy : (data -> comparable) -> Sorter data
increasingOrDecreasingBy toComparable =
    IncOrDec (List.sortBy toComparable)



-- VIEW


list : Config data msg -> State -> (data -> List (Html msg)) -> List data -> Html msg
list { columns } state toListItem data =
    let
        sortedData =
            sort state columns data

        listItem d =
            li [] (toListItem d)
    in
    ul [] <| List.map listItem sortedData


table : Config data msg -> State -> List data -> Html msg
table { toId, toMsg, columns } state data =
    let
        sortedData =
            sort state columns data
    in
    Table.table [ css [ fontSize (px 14) ] ]
        [ thead []
            [ tr [] <|
                List.map (toHeaderInfo state toMsg >> simpleTheadHelp) columns
            ]
        , Keyed.node "tbody" [] <|
            List.map (tableRow toId columns) sortedData
        ]


toHeaderInfo : State -> (State -> msg) -> Column data msg -> ( String, Status, Attribute msg )
toHeaderInfo (State sortName isReversed) toMsg { name, sorter } =
    case sorter of
        None ->
            ( name, Unsortable, onClick sortName isReversed toMsg )

        Increasing _ ->
            ( name, Sortable (name == sortName), onClick name False toMsg )

        Decreasing _ ->
            ( name, Sortable (name == sortName), onClick name False toMsg )

        IncOrDec _ ->
            if name == sortName then
                ( name, Reversible (Just isReversed), onClick name (not isReversed) toMsg )

            else
                ( name, Reversible Nothing, onClick name False toMsg )

        DecOrInc _ ->
            if name == sortName then
                ( name, Reversible (Just isReversed), onClick name (not isReversed) toMsg )

            else
                ( name, Reversible Nothing, onClick name False toMsg )


onClick : String -> Bool -> (State -> msg) -> Attribute msg
onClick name isReversed toMsg =
    Events.on "click" <|
        Json.map toMsg <|
            Json.map2 State (Json.succeed name) (Json.succeed isReversed)


simpleTheadHelp : ( String, Status, Attribute msg ) -> Html msg
simpleTheadHelp ( name, status, onClick_ ) =
    let
        symbol =
            case status of
                Unsortable ->
                    []

                Sortable selected ->
                    [ if selected then
                        darkGrey "↓"

                      else
                        lightGrey "↓"
                    ]

                Reversible Nothing ->
                    [ lightGrey "↕" ]

                Reversible (Just isReversed) ->
                    [ if isReversed then
                        darkGrey "↑"

                      else
                        darkGrey "↓"
                    ]

        content =
            text (name ++ " ") :: symbol
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
    List
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


view_ :
    { tableState : State
    , raceClock : Clock
    , analysis : Analysis
    , toMsg : State -> msg
    , coefficient : Float
    }
    -> Leaderboard
    -> Html msg
view_ { tableState, raceClock, analysis, toMsg, coefficient } data =
    let
        config =
            { toId = .carNumber
            , toMsg = toMsg
            , columns =
                [ intColumn { label = "Position", getter = .position }
                , stringColumn { label = "#", getter = .carNumber }
                , stringColumn { label = "Driver", getter = .driver }
                , intColumn { label = "Lap", getter = .lap }
                , customColumn
                    { label = "Gap"
                    , getter = .gap >> Gap.toString
                    , sorter = increasingOrDecreasingBy .position
                    }
                , veryCustomColumn
                    { label = "Gap"
                    , getter =
                        \{ gap } ->
                            case gap of
                                Gap.None ->
                                    text "-"

                                Seconds duration ->
                                    gap_ duration

                                Laps _ ->
                                    text "-"
                    , sorter = increasingOrDecreasingBy .position
                    }
                , veryCustomColumn
                    { label = "Time"
                    , getter =
                        \item ->
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
                    , sorter = increasingOrDecreasingBy .time
                    }
                , veryCustomColumn
                    { label = "Time"
                    , getter = .history >> performance raceClock analysis coefficient
                    , sorter = increasingOrDecreasingBy .time
                    }
                , veryCustomColumn
                    { label = "Histogram"
                    , getter = .history >> histogram analysis coefficient
                    , sorter = increasingOrDecreasingBy .time
                    }
                ]
            }
    in
    table config tableState data


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
