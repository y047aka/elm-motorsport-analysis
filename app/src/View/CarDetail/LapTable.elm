module View.CarDetail.LapTable exposing (view)

{-| Every lap the car has turned, as it was timed, in the order it was driven.

@docs view

-}

import Html exposing (Html, div, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (class, colspan, style)
import Html.Lazy as Lazy
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Lap.Performance as Performance exposing (RatedTime)
import Motorsport.Race.Stint as RaceStint exposing (Stint)
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

The rows are cut into the stints they were driven in, each under a heading
naming its driver, by the same `Motorsport.Race.Stint` reading as the section
above.

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
                            (heading "Lap" :: heading "Time" :: List.map (Sector.toString >> heading) Sector.all ++ [ heading "Pit" ])
                        ]
                    , tbody [] (List.concatMap (stintRows completed) (RaceStint.fromLaps completed))
                    ]
                ]


stintRows : List Lap -> Stint -> List (Html msg)
stintRows completed stint =
    stintHeading stint
        :: (completed
                |> List.filter (\lap -> lap.lap >= stint.firstLap && lap.lap <= stint.lastLap)
                |> List.sortBy .lap
                |> List.map row
           )


stintHeading : Stint -> Html msg
stintHeading stint =
    tr [ class "border-t border-t-border" ]
        [ td
            [ colspan (2 + List.length Sector.all + 1)
            , class "py-1 px-1 text-[9px] uppercase tracking-[0.03em] text-muted-foreground"
            ]
            [ text
                ("Stint "
                    ++ String.fromInt stint.number
                    ++ " · "
                    ++ Driver.toInitialAndSurname stint.driver
                )
            ]
        ]


heading : String -> Html msg
heading label =
    th [ class "py-0.5 px-1 text-right font-normal" ] [ text label ]


row : Lap -> Html msg
row lap =
    tr [ class "border-t border-t-border" ]
        (td [ class "py-0.5 px-1 text-right" ] [ text (String.fromInt lap.lap) ]
            :: timeCell (againstOwnBest { time = lap.time, personalBest = lap.best })
            :: (Sector.values lap.sectors |> List.map (againstOwnBest >> timeCell))
            ++ [ td [ class "py-0.5 px-1 text-right text-muted-foreground" ]
                    [ text (pitCell lap) ]
               ]
        )


pitCell : Lap -> String
pitCell lap =
    case lap.pit of
        Lap.NoPit ->
            ""

        Lap.InLap ->
            "in"

        Lap.OutLap duration ->
            Duration.toString duration

        Lap.OutAndIn duration ->
            Duration.toString duration ++ " in"


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
