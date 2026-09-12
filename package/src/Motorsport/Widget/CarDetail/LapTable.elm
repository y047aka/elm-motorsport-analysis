module Motorsport.Widget.CarDetail.LapTable exposing (view)

{-| The car's laps as they were timed, newest first.

Every chart on the page reads these laps and draws them as a shape; this is the
numbers themselves, which is what a shape cannot be checked against.

@docs view

-}

import Html exposing (Html, div, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (class, style)
import Motorsport.BestTimes as BestTimes
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration
import Motorsport.Lap exposing (Lap)
import Motorsport.Lap.Performance as Performance exposing (RatedTime)
import Motorsport.Sector as Sector


{-| The most recent laps only: the whole of a Le Mans is four hundred rows, and
what a table is read for is the last few and the one a chart just raised a
question about.
-}
recentLimit : Int
recentLimit =
    40


view : BestTimes.Snapshot -> List Lap -> Html msg
view bestTimes laps =
    case laps of
        [] ->
            div [ class "text-[11px] text-muted-foreground" ] [ text "No laps completed" ]

        _ ->
            div [ class "max-h-[320px] overflow-y-auto" ]
                [ table [ class "w-full border-collapse text-[11px] tabular-nums" ]
                    [ thead [ class "sticky top-0 bg-background" ]
                        [ tr [ class "text-[9px] uppercase tracking-[0.03em] text-muted-foreground" ]
                            (heading "Lap" :: heading "Driver" :: heading "Time" :: List.map (Sector.toString >> heading) Sector.all ++ [ heading "Pit" ])
                        ]
                    , tbody []
                        (laps
                            |> List.sortBy (.lap >> negate)
                            |> List.take recentLimit
                            |> List.map (row bestTimes)
                        )
                    ]
                ]


heading : String -> Html msg
heading label =
    th [ class "py-0.5 px-1 text-right font-normal first:text-left" ] [ text label ]


row : BestTimes.Snapshot -> Lap -> Html msg
row bestTimes lap =
    tr [ class "border-t border-t-border" ]
        (td [ class "py-0.5 px-1" ] [ text (String.fromInt lap.lap) ]
            :: td [ class "py-0.5 px-1 text-right text-muted-foreground" ]
                [ text (Driver.toSurname lap.driver) ]
            :: timeCell
                (Performance.rateTime (BestTimes.timeOf bestTimes.fastestLapTime)
                    { time = lap.time, personalBest = lap.best }
                )
            :: (Performance.ofSectors bestTimes lap
                    |> Sector.values
                    |> List.map timeCell
               )
            ++ [ td [ class "py-0.5 px-1 text-right text-muted-foreground" ]
                    [ text (lap.pitTime |> Maybe.map Duration.toString |> Maybe.withDefault "") ]
               ]
        )


timeCell : Maybe RatedTime -> Html msg
timeCell rated =
    td
        [ class "py-0.5 px-1 text-right"
        , style "color" (rated |> Maybe.map (.performance >> Performance.toColorVariable) |> Maybe.withDefault "inherit")
        ]
        [ text (rated |> Maybe.map (.time >> Duration.toString) |> Maybe.withDefault "-") ]
