module Motorsport.Widget.CarDetail.LapTable exposing (view)

{-| Every lap the car has turned, as it was timed, newest first.

Every chart on the page reads these laps and draws them as a shape; this is the
numbers themselves, which is what a shape cannot be checked against -- so the lap
a chart raised a question about is in here whichever lap it was.

@docs view

-}

import Html exposing (Html, div, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (class, style)
import Html.Lazy as Lazy
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap exposing (Lap)
import Motorsport.Lap.Performance as Performance exposing (RatedTime)
import Motorsport.Sector as Sector


{-| `laps` is the car's whole race and `lapsCompleted` is how far the clock has
got through it, rather than the laps already cut at the clock: the cut list is
built afresh every frame and would have four hundred rows built again with it.
What is passed here is the race's own list, which never moves, and a number -- so
the rows are built again only when a lap is added to them.

Each time is rated against the driver's best up to the lap it was set on, which
is the baseline the lap carries. The race's records are not read: a table of one
car's laps is the one place a colour for "quickest of sixty-two cars" never
fires, while the lap that moved this car's own best is on every one of them.

-}
view : List Lap -> Int -> Html msg
view laps lapsCompleted =
    Lazy.lazy2 rows laps lapsCompleted


rows : List Lap -> Int -> Html msg
rows laps lapsCompleted =
    case List.filter (\lap -> lap.lap <= lapsCompleted) laps of
        [] ->
            div [ class "text-[11px] text-muted-foreground" ] [ text "No laps completed" ]

        completed ->
            div [ class "max-h-[320px] overflow-y-auto" ]
                [ table [ class "w-full border-collapse text-[11px] tabular-nums" ]
                    [ thead [ class "sticky top-0 bg-background" ]
                        [ tr [ class "text-[9px] uppercase tracking-[0.03em] text-muted-foreground" ]
                            (heading "Lap" :: heading "Driver" :: heading "Time" :: List.map (Sector.toString >> heading) Sector.all ++ [ heading "Pit" ])
                        ]
                    , tbody []
                        (completed
                            |> List.sortBy (.lap >> negate)
                            |> List.map row
                        )
                    ]
                ]


heading : String -> Html msg
heading label =
    th [ class "py-0.5 px-1 text-right font-normal first:text-left" ] [ text label ]


row : Lap -> Html msg
row lap =
    tr [ class "border-t border-t-border" ]
        (td [ class "py-0.5 px-1" ] [ text (String.fromInt lap.lap) ]
            :: td [ class "py-0.5 px-1 text-right text-muted-foreground" ]
                [ text (Driver.toSurname lap.driver) ]
            :: timeCell (againstOwnBest { time = lap.time, personalBest = lap.best })
            :: (Sector.values lap.sectors |> List.map (againstOwnBest >> timeCell))
            ++ [ td [ class "py-0.5 px-1 text-right text-muted-foreground" ]
                    [ text (lap.pitTime |> Maybe.map Duration.toString |> Maybe.withDefault "") ]
               ]
        )


againstOwnBest : { time : Maybe Duration, personalBest : Maybe Duration } -> Maybe RatedTime
againstOwnBest =
    Performance.rateTime Nothing


timeCell : Maybe RatedTime -> Html msg
timeCell rated =
    td
        [ class "py-0.5 px-1 text-right"
        , style "color" (rated |> Maybe.map (.performance >> Performance.toColorVariable) |> Maybe.withDefault "inherit")
        ]
        [ text (rated |> Maybe.map (.time >> Duration.toString) |> Maybe.withDefault "-") ]
