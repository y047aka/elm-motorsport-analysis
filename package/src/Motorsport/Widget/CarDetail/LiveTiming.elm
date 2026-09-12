module Motorsport.Widget.CarDetail.LiveTiming exposing (view)

{-| What the car is doing right now: the lap it is on, the lap it has just
finished, and how its own best stands against the race's.

The strip a timing screen has room for is a bar per sector; a panel given the
middle of the page has room for the times those bars are drawn from, and for the
mini-sectors the circuit records them at.

@docs view

-}

import Html exposing (Html, div, text)
import Html.Attributes exposing (class, style)
import Motorsport.BestTimes as BestTimes exposing (Holder)
import Motorsport.Duration as Duration
import Motorsport.Lap.Performance as Performance exposing (RatedTime, SegmentState)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt)
import Motorsport.Sector as Sector
import Motorsport.Wec.Circuit.LeMans as LeMans
import Motorsport.Widget.SectorAndLaps as SectorAndLaps


view : BestTimes.Snapshot -> CarAt -> Html msg
view bestTimes item =
    div [ class "grid gap-y-3" ]
        [ SectorAndLaps.view item
        , div [ class "grid gap-y-2" ]
            [ segmentRow "Current lap" (currentSectors item)
            , segmentRow "Last lap" (lastSectors item)
            ]
        , lastMiniSectors item
        , bestLap bestTimes item
        ]


segmentRow : String -> List (Html msg) -> Html msg
segmentRow label cells =
    div [ class "grid gap-y-1" ]
        [ rowLabel label
        , div [ class "grid grid-cols-3 gap-x-2" ] cells
        ]


rowLabel : String -> Html msg
rowLabel label =
    div [ class "text-[9px] uppercase tracking-[0.03em] text-muted-foreground" ]
        [ text label ]


{-| The sectors of the lap the car is on: how far it has got through the one it
is in, and the time of each it has behind it.
-}
currentSectors : CarAt -> List (Html msg)
currentSectors item =
    Sector.toList item.currentLap.sectorStates
        |> List.map
            (\( sector, state ) ->
                segmentCell
                    { label = Sector.toString sector
                    , rated = Performance.ratedOf state
                    , fill = fillOf state
                    }
            )


lastSectors : CarAt -> List (Html msg)
lastSectors item =
    let
        rated =
            case item.lastLap of
                Snapshot.Completed completed ->
                    Sector.toList completed.sectors |> List.map Tuple.second

                Snapshot.NoLapYet ->
                    List.repeat 3 Nothing
    in
    List.map2
        (\sector rating ->
            segmentCell
                { label = Sector.toString sector
                , rated = rating
                , fill =
                    if rating == Nothing then
                        Empty

                    else
                        Whole (colorOfRated rating)
                }
        )
        Sector.all
        rated


{-| Each mini-sector of the last lap by name, which is the grain the circuit
times at and the one a bar of fifteen cells cannot be read at.
-}
lastMiniSectors : CarAt -> Html msg
lastMiniSectors item =
    case item.lastLap of
        Snapshot.Completed { miniSectors } ->
            case miniSectors of
                Just rated ->
                    div [ class "grid gap-y-1" ]
                        [ rowLabel "Last lap mini sectors"
                        , div [ class "grid grid-cols-[repeat(auto-fill,minmax(70px,1fr))] gap-1" ]
                            (LeMans.toList rated
                                |> List.map
                                    (\( mini, rating ) ->
                                        segmentCell
                                            { label = LeMans.toString mini
                                            , rated = rating
                                            , fill =
                                                if rating == Nothing then
                                                    Empty

                                                else
                                                    Whole (colorOfRated rating)
                                            }
                                    )
                            )
                        ]

                Nothing ->
                    text ""

        Snapshot.NoLapYet ->
            text ""


{-| One segment of a lap: what it is called, how much of it is behind the car,
and its time once all of it is.
-}
segmentCell : { label : String, rated : Maybe RatedTime, fill : Fill } -> Html msg
segmentCell { label, rated, fill } =
    div [ class "grid gap-y-0.5" ]
        [ div [ class "flex items-baseline justify-between gap-x-1" ]
            [ div [ class "text-[9px] text-muted-foreground" ] [ text label ]
            , div
                [ class "text-[12px] tabular-nums"
                , style "color" (rated |> Maybe.map (.performance >> Performance.toColorVariable) |> Maybe.withDefault "inherit")
                ]
                [ text (rated |> Maybe.map (.time >> Duration.toString) |> Maybe.withDefault "-") ]
            ]
        , fillBar fill
        ]


type Fill
    = Empty
    | Partial Float
    | Whole String


fillOf : SegmentState -> Fill
fillOf state =
    case state of
        Performance.NotEntered ->
            Empty

        Performance.InProgress progress ->
            Partial progress

        Performance.Completed rated ->
            Whole (colorOfRated rated)


fillBar : Fill -> Html msg
fillBar fill =
    let
        ( width, color ) =
            case fill of
                Empty ->
                    ( "0%", "transparent" )

                Partial progress ->
                    ( String.fromFloat (progress * 100) ++ "%", "oklch(1 0 0)" )

                Whole color_ ->
                    ( "100%", color_ )
    in
    div [ class "h-[3px] rounded-[1px] bg-border" ]
        [ div
            [ class "h-full rounded-[1px]"
            , style "width" width
            , style "background-color" color
            ]
            []
        ]


{-| The car's own best against the race's, which is the only baseline in the
data that says whether the car is quick or merely consistent.
-}
bestLap : BestTimes.Snapshot -> CarAt -> Html msg
bestLap bestTimes item =
    div [ class "grid gap-y-1" ]
        [ rowLabel "Best lap"
        , div [ class "flex flex-wrap items-baseline gap-x-3 text-[12px] tabular-nums" ]
            [ div
                [ style "color" (item.bestLap |> Maybe.map (.performance >> Performance.toColorVariable) |> Maybe.withDefault "inherit") ]
                [ text (item.bestLap |> Maybe.map (.time >> Duration.toString) |> Maybe.withDefault "-") ]
            , div [ class "text-[11px] text-muted-foreground" ]
                [ text (againstRace bestTimes.fastestLapTime item.bestLap) ]
            ]
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
                    ++ " "
                    ++ Duration.toString holder.time

        _ ->
            ""


colorOfRated : Maybe RatedTime -> String
colorOfRated =
    Maybe.map .performance
        >> Maybe.withDefault Performance.Standard
        >> Performance.toColorVariable
