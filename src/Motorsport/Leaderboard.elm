module Motorsport.Leaderboard exposing
    ( stringColumn, intColumn, floatColumn
    , Model, initialSort
    , Msg, update
    , customColumn, veryCustomColumn
    , timeColumn, histogramColumn, performanceColumn
    , driverNameColumn_F1, driverAndTeamColumn_Wec
    , Config, Leaderboard, LeaderboardItem, init, view
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
@docs driverNameColumn_F1, driverAndTeamColumn_Wec

-}

import Css exposing (Color, backgroundColor, batch, borderLeft3, borderRadius, color, column, displayFlex, firstChild, flexDirection, fontSize, height, hex, hsl, lastChild, nthChild, pct, property, px, solid, width)
import Html.Styled as Html exposing (Attribute, Html, div, span, text)
import Html.Styled.Attributes exposing (css)
import Html.Styled.Events exposing (onClick)
import Html.Styled.Keyed as Keyed
import Html.Styled.Lazy exposing (lazy2)
import List.Extra
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Car exposing (Car)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap(..))
import Motorsport.Lap as Lap exposing (Lap, completedLapsAt, findLastLapAt)
import Motorsport.LapStatus as LapStatus exposing (lapStatus)
import Motorsport.RaceControl as RaceControl
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
                            [ let
                                status =
                                    lapStatus { time = analysis.fastestLapTime } item
                              in
                              if LapStatus.isNormal status then
                                batch []

                              else
                                LapStatus.toHexColorString status
                                    |> hex
                                    |> color
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
    , analysis : Analysis
    }
    -> Column data msg
performanceColumn { getter, sorter, analysis } =
    { name = "Performance"
    , view = getter >> performanceHistory analysis
    , sorter = sorter
    }


driverNameColumn_F1 : { label : String, getter : data -> String } -> Column data msg
driverNameColumn_F1 { label, getter } =
    let
        formatName name =
            String.split " " name
                |> List.reverse
                |> List.head
                |> Maybe.map String.toUpper
                |> Maybe.withDefault ""
    in
    { name = label
    , view = getter >> formatName >> text
    , sorter = List.sortBy getter
    }


driverAndTeamColumn_Wec : { label : String, driver : data -> String, team : data -> String } -> Column data msg
driverAndTeamColumn_Wec { label, driver, team } =
    let
        formatName name =
            String.split " " name
                |> List.Extra.unconsLast
                |> Maybe.map (\( lastName, rest ) -> String.join "." (List.map (String.left 1) rest ++ [ String.toUpper lastName ]))
                |> Maybe.withDefault (String.toUpper name)
    in
    { name = label
    , view =
        \data ->
            div [ css [ displayFlex, flexDirection column, property "row-gap" "5px" ] ]
                [ div [] [ text (team data) ]
                , div [ css [ fontSize (px 10) ] ] [ driver data |> formatName |> text ]
                ]
    , sorter = List.sortBy team
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


view : Config LeaderboardItem msg -> Model -> RaceControl.Model -> Html msg
view config state raceControl =
    let
        leaderboardData =
            init raceControl

        sortedData =
            sort state config.columns leaderboardData
    in
    viewHelper config state sortedData


viewHelper : Config data msg -> Model -> List data -> Html msg
viewHelper { toId, toMsg, columns } state data =
    Table.table [ css [ fontSize (px 14) ] ]
        [ thead []
            [ tr [] <|
                List.map (toHeaderInfo state.sorting toMsg >> simpleTheadHelp) columns
            ]
        , Keyed.node "tbody" [] <|
            List.map (tableRow toId columns) data
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



-- PREVIOUS LEADERBOARD


type alias Leaderboard =
    List LeaderboardItem


type alias LeaderboardItem =
    { position : Int
    , carNumber : String
    , driver : String
    , team : String
    , lap : Int
    , gap : Gap
    , time : Duration
    , best : Duration
    , history : List Lap
    }


init : RaceControl.Model -> Leaderboard
init ({ raceClock } as raceControl) =
    let
        sortedCars =
            sortCarsAt raceControl
    in
    sortedCars
        |> List.indexedMap
            (\index { car, lastLap } ->
                { position = index + 1
                , driver = car.driverName
                , carNumber = car.carNumber
                , team = car.team
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


sortCarsAt : RaceControl.Model -> List { car : Car, lastLap : Lap }
sortCarsAt { raceClock, cars } =
    cars
        |> List.map
            (\car ->
                let
                    lastLap =
                        findLastLapAt raceClock car.laps
                            |> Maybe.withDefault { carNumber = "", driver = "", lap = 0, position = Nothing, time = 0, best = 0, elapsed = 0 }
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
            if isCurrentLap lap then
                lapStatus { time = fastestLapTime } lap
                    |> LapStatus.toHexColorString

            else
                "hsla(0, 0%, 100%, 0.2)"

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


performanceHistory : { a | fastestLapTime : Duration } -> List Lap -> Html msg
performanceHistory analysis laps =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "repeat(7, auto)"
            ]
        ]
        [ performanceHistory_ analysis laps ]


performanceHistory_ : { a | fastestLapTime : Duration } -> List Lap -> Html msg
performanceHistory_ { fastestLapTime } laps =
    let
        toCssColor lap =
            (lapStatus { time = fastestLapTime } >> LapStatus.toHexColorString >> hex) lap
    in
    div
        [ css
            [ property "padding-inline" "0.3vw"
            , property "display" "grid"
            , property "grid-auto-flow" "column"
            , property "grid-auto-columns" "max(5px, 0.3vw)"
            , property "grid-template-rows" "repeat(5, max(5px, 0.3vw))"
            , property "gap" "1.5px"
            , firstChild
                [ property "padding-inline-start" "0" ]
            , nthChild "n+2"
                [ borderLeft3 (px 1) solid (hsl 0 0 0) ]
            , lastChild
                [ property "padding-inline-end" "0" ]
            ]
        ]
        (List.map (\lap -> coloredCell (toCssColor lap)) laps)


coloredCell : Color -> Html msg
coloredCell backgroundColor_ =
    div
        [ css
            [ width (pct 100)
            , height (pct 100)
            , borderRadius (pct 10)
            , backgroundColor backgroundColor_
            ]
        ]
        []
