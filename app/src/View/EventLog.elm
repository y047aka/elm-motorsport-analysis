module View.EventLog exposing (rows)

{-| The Log section of a car detail panel: one car's lines, newest first.

What the lines are is [`CarLog`](Motorsport-Analysis-CarLog)'s, read off the
timeline and the car's own laps; this module is only how they are ruled.

@docs rows

-}

import Html exposing (Html, div, span, text)
import Html.Attributes exposing (class, style)
import List.Extra
import Motorsport.Analysis.CarLog as CarLog
import Motorsport.Duration as Duration
import Motorsport.Instant as Instant
import Motorsport.Lap.Performance as Performance
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Race.Snapshot as Snapshot exposing (Snapshot)
import Motorsport.Race.Timeline exposing (Timeline)
import UI.EmptyState as EmptyState


{-| One car's lines by the panel's clock, newest first, at most `recentLimit`
of them.
-}
rows : List Car -> Timeline -> Snapshot -> CarNumber -> Html msg
rows cars timeline snapshot carNumber =
    let
        lines =
            cars
                |> List.Extra.find (\car -> car.metadata.carNumber == carNumber)
                |> Maybe.map (\car -> CarLog.lines { elapsed = Snapshot.elapsed snapshot } car timeline)
                |> Maybe.withDefault []
                |> List.take recentLimit
    in
    if List.isEmpty lines then
        EmptyState.view "Nothing has happened to this car yet"

    else
        div [ class "grid gap-y-px text-xs" ]
            (List.map lineRow lines)


recentLimit : Int
recentLimit =
    100


lineRow : CarLog.Line -> Html msg
lineRow line =
    div [ class "grid grid-cols-[2rem_1fr_auto] gap-x-2 items-baseline py-0.5" ]
        [ div [ class "text-right tabular-nums text-muted-foreground" ]
            [ text (Maybe.map String.fromInt line.lap |> Maybe.withDefault "-") ]
        , div [ class "truncate", style "color" (Performance.textColorOf line.level) ]
            [ text line.label

            -- The colour the row carries is the rating, which rates the lap time and
            -- not the driver beside it.
            , case line.by of
                Just second ->
                    span [ class "text-foreground" ] [ text (" · " ++ second) ]

                Nothing ->
                    text ""
            ]
        , div [ class "tabular-nums text-muted-foreground" ]
            [ text (line.at |> Instant.toDuration |> Duration.toStringToSeconds) ]
        ]
