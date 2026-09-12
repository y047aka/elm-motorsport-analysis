module Motorsport.Widget.CarDetail.LapTimes exposing (view)

{-| The car's lap times, newest first: the lap it is driving, the lap it has
just finished, the best it has turned, and every lap behind those.

The whole page is a timing screen, so nothing here is labelled live. What the
section is for is the one thing a timing screen is short of room for: the lap in
progress measured against something -- each sector of it against the best the car
has managed, which is the reading that says whether this lap is going anywhere
before it is over.

@docs view

-}

import Html exposing (Html, button, div, text)
import Html.Attributes exposing (attribute, class, style)
import Html.Events exposing (onClick)
import Motorsport.BestTimes as BestTimes exposing (Holder)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap exposing (Lap)
import Motorsport.Lap.Performance as Performance exposing (RatedTime)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt)
import Motorsport.Sector as Sector exposing (BySector, Sector)
import Motorsport.Status as Status
import Motorsport.Widget.CarDetail.LapTable as LapTable
import Motorsport.Widget.SegmentStrip as SegmentStrip


{-| `laps` is the car's whole race, as the race holds it rather than cut at the
clock: what the sectors of the lap in progress are measured against, and -- once
the reader asks for them -- the rows under everything else. The cut is made here
at the lap the car has reached, so that the list handed down is the one that
never moves and the rows below can be left alone between laps.
-}
view :
    { bestTimes : BestTimes.Snapshot
    , historyOpen : Bool
    , onToggleHistory : msg
    }
    -> List Lap
    -> CarAt
    -> Html msg
view config laps item =
    div [ class "grid gap-y-2" ]
        [ if Status.hasStopped item.status then
            text ""

          else
            currentLap (bestSectors item.standing.lapsCompleted laps) item
        , lastLap item
        , bestLap config.bestTimes item
        , history config laps item.standing.lapsCompleted
        ]


{-| Every lap the car has turned, under the three the section leads with.

Kept behind a disclosure rather than beside the charts: the charts are the car
against the cars it is racing, and a list of its own laps is not that -- it is
the rest of this section, at the grain the section is about.

-}
history : { a | historyOpen : Bool, onToggleHistory : msg } -> List Lap -> Int -> Html msg
history { historyOpen, onToggleHistory } laps lapsCompleted =
    div [ class "grid gap-y-1 border-t border-t-border pt-1.5" ]
        [ button
            [ onClick onToggleHistory
            , attribute "aria-expanded"
                (if historyOpen then
                    "true"

                 else
                    "false"
                )
            , class "flex items-center gap-x-1 text-[9px] uppercase tracking-[0.03em] text-muted-foreground cursor-pointer hover:text-foreground transition-colors"
            ]
            [ div [ class "text-[8px]" ]
                [ text
                    (if historyOpen then
                        "▼"

                     else
                        "▶"
                    )
                ]
            , text "Lap history"
            ]
        , if historyOpen then
            LapTable.view laps lapsCompleted

          else
            text ""
        ]



-- THE LAP IN PROGRESS


currentLap : BySector (Maybe Duration) -> CarAt -> Html msg
currentLap best item =
    lapBlock
        { label = "Current"
        , lapNumber = Just (item.standing.lapsCompleted + 1)
        , time = Just { time = item.currentLap.elapsed, performance = item.currentLap.performance }
        , sectors =
            Sector.toList item.currentLap.sectorStates
                |> List.map (\( sector, state ) -> sectorCell (Sector.get sector best) sector (Performance.ratedOf state))
        , strip =
            case item.currentLap.miniSectors of
                Snapshot.Recorded { states } ->
                    Just (SegmentStrip.miniSectors states)

                Snapshot.NotRecorded ->
                    Just (SegmentStrip.sectors item.currentLap.sectorStates)
        }


{-| The best each sector has been driven in, over the laps the car has finished.

Laps the car pitted on are left out, as they are everywhere else a pace is read:
the stop is in that lap's final sector, and a sector nothing can beat is no
baseline at all. So are the laps the clock has not reached: a lap the car is
going to run is not a lap it has driven.

-}
bestSectors : Int -> List Lap -> BySector (Maybe Duration)
bestSectors lapsCompleted laps =
    let
        racingLaps =
            List.filter (\lap -> lap.pitTime == Nothing && lap.lap <= lapsCompleted) laps
    in
    Sector.initialize
        (\sector ->
            racingLaps
                |> List.filterMap (\lap -> (Sector.get sector lap.sectors).time)
                |> List.minimum
        )



-- THE LAPS BEHIND IT


lastLap : CarAt -> Html msg
lastLap item =
    case item.lastLap of
        Snapshot.Completed { rated, sectors, miniSectors } ->
            lapBlock
                { label = "Last"
                , lapNumber = Just item.standing.lapsCompleted
                , time = rated
                , sectors =
                    Sector.toList sectors
                        |> List.map (\( sector, rating ) -> sectorCell Nothing sector rating)
                , strip = Maybe.map SegmentStrip.miniSectorsRated miniSectors
                }

        Snapshot.NoLapYet ->
            lapBlock
                { label = "Last"
                , lapNumber = Nothing
                , time = Nothing
                , sectors = List.map (\sector -> sectorCell Nothing sector Nothing) Sector.all
                , strip = Nothing
                }


{-| The car's own best against the race's, which is the only baseline in the
data that says whether the car is quick or merely consistent.
-}
bestLap : BestTimes.Snapshot -> CarAt -> Html msg
bestLap bestTimes item =
    div [ class "flex items-baseline gap-x-2" ]
        [ rowLabel "Best"
        , timeText "text-[13px]" item.bestLap
        , div [ class "text-[10px] text-muted-foreground truncate" ]
            [ text (againstRace bestTimes.fastestLapTime item.bestLap) ]
        ]


againstRace : Maybe Holder -> Maybe RatedTime -> String
againstRace fastest best =
    case ( fastest, best ) of
        ( Just holder, Just own ) ->
            let
                delta =
                    own.time - holder.time
            in
            if delta == 0 then
                "fastest of the race"

            else
                "+"
                    ++ Duration.toString delta
                    ++ " on #"
                    ++ holder.carNumber
                    ++ " L"
                    ++ String.fromInt holder.lap

        _ ->
            ""



-- ONE LAP


{-| A lap as one block: what it is and how long it has taken, its three sectors,
and the strip of the segments the circuit times it in.
-}
lapBlock :
    { label : String
    , lapNumber : Maybe Int
    , time : Maybe RatedTime
    , sectors : List (Html msg)
    , strip : Maybe (Html msg)
    }
    -> Html msg
lapBlock { label, lapNumber, time, sectors, strip } =
    div [ class "grid gap-y-1" ]
        [ div [ class "flex items-baseline gap-x-2" ]
            [ rowLabel label
            , div [ class "text-[10px] text-muted-foreground tabular-nums" ]
                [ text (lapNumber |> Maybe.map (\number -> "L" ++ String.fromInt number) |> Maybe.withDefault "") ]
            , div [ class "flex-1" ] []
            , timeText "text-[14px]" time
            ]
        , div [ class "grid grid-cols-3 gap-x-2" ] sectors
        , strip |> Maybe.withDefault (text "")
        ]


{-| One sector of a lap: its time, and -- where there is a best to measure it
against -- how far off that best it was. A sector under way has neither yet.
-}
sectorCell : Maybe Duration -> Sector -> Maybe RatedTime -> Html msg
sectorCell best sector rated =
    div [ class "flex items-baseline gap-x-1" ]
        [ div [ class "text-[9px] text-muted-foreground" ] [ text (Sector.toString sector) ]
        , timeText "text-[12px]" rated
        , div [ class "text-[10px] tabular-nums text-muted-foreground" ]
            [ text (deltaOf best rated) ]
        ]


{-| How the sector compares with the best the car has driven it in.

The best is taken over the laps the car has finished, so the lap in progress is
not in it: a sector quicker than anything before it comes out negative rather
than as a zero.

-}
deltaOf : Maybe Duration -> Maybe RatedTime -> String
deltaOf best rated =
    case ( best, rated ) of
        ( Just baseline, Just time ) ->
            let
                delta =
                    time.time - baseline
            in
            if delta > 0 then
                "+" ++ Duration.toString delta

            else
                Duration.toString delta

        _ ->
            ""


timeText : String -> Maybe RatedTime -> Html msg
timeText size rated =
    div
        [ class (size ++ " tabular-nums")
        , style "color" (rated |> Maybe.map (.performance >> Performance.toColorVariable) |> Maybe.withDefault "inherit")
        ]
        [ text (rated |> Maybe.map (.time >> Duration.toString) |> Maybe.withDefault "-") ]


rowLabel : String -> Html msg
rowLabel label =
    div [ class "text-[9px] uppercase tracking-[0.03em] text-muted-foreground" ]
        [ text label ]
