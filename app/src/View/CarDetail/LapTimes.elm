module View.CarDetail.LapTimes exposing (view)

{-| The car's lap times, newest first: the lap it is driving, the lap it has
just finished, the best it has turned, and every lap behind those.

The whole page is a timing screen, so nothing here is labelled live. What the
section is for is the one thing a timing screen is short of room for: the lap in
progress measured against something -- each sector of it against the best the car
has managed, which is the reading that says whether this lap is going anywhere
before it is over.

@docs view

-}

import Html exposing (Html, div, text)
import Html.Attributes exposing (class, style)
import Motorsport.Analysis.Pace as Pace
import Motorsport.BestTimes as BestTimes exposing (Holder)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap exposing (Lap)
import Motorsport.Lap.Performance as Performance exposing (RatedTime)
import Motorsport.Lap.SegmentStrip as SegmentStrip
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt)
import Motorsport.Sector as Sector exposing (BySector)
import Motorsport.Status as Status


{-| `laps` is the car's whole race, as the race holds it rather than cut at the
clock: what the sectors of the lap in progress are measured against. The section
cuts it at the lap the car has reached itself.
-}
view :
    { bestTimes : BestTimes.Snapshot }
    -> List Lap
    -> CarAt
    -> Html msg
view config laps item =
    let
        best =
            Pace.bestSectors { first = 1, last = item.standing.lapsCompleted } laps
    in
    div [ class "grid gap-y-2" ]
        [ bestLap config.bestTimes item
        , -- One above the other, each across the panel: half of it each is
          -- not enough for three sector times, the middle sector of a GT3 car
          -- running over a minute.
          --
          -- One grid between the two rather than one apiece, so that the rail
          -- is as wide as the wider of them and the sectors of the two laps
          -- begin at the same place -- `CURRENT L28` is longer than
          -- `LAST L27`, which is enough to set two rows of segments out from
          -- one another.
          div [ class "grid grid-cols-[auto_minmax(0,1fr)] items-center gap-x-3 gap-y-2" ]
            (if Status.hasStopped item.status then
                lastLap item

             else
                currentLap best item ++ lastLap item
            )
        ]



-- THE LAP IN PROGRESS


currentLap : BySector (Maybe Duration) -> CarAt -> List (Html msg)
currentLap best item =
    let
        cells =
            Sector.map2 (\baseline state -> deltaCell baseline (Performance.ratedOf state))
                best
                item.currentLap.sectorStates
    in
    lapBlock
        { label = "Current"
        , lapNumber = Just (item.standing.lapsCompleted + 1)
        , time = Just { time = item.currentLap.elapsed, performance = item.currentLap.performance }
        , segments =
            case item.currentLap.miniSectors of
                Snapshot.Recorded { states } ->
                    SegmentStrip.overMiniSectors
                        { cells = cells, strip = SegmentStrip.miniSectors states }

                Snapshot.NotRecorded ->
                    SegmentStrip.overSectors
                        { cells = cells
                        , strip = SegmentStrip.sectors item.currentLap.sectorStates
                        }
        }



-- THE LAPS BEHIND IT


lastLap : CarAt -> List (Html msg)
lastLap item =
    case item.lastLap of
        Snapshot.Completed { rated, sectors, miniSectors } ->
            let
                cells =
                    Sector.initialize (\sector -> timeCell (Sector.get sector sectors))
            in
            lapBlock
                { label = "Last"
                , lapNumber = Just item.standing.lapsCompleted
                , time = rated
                , segments =
                    case miniSectors of
                        Just rating ->
                            SegmentStrip.overMiniSectors
                                { cells = cells, strip = SegmentStrip.miniSectorsRated rating }

                        Nothing ->
                            SegmentStrip.overSectors
                                { cells = cells, strip = SegmentStrip.sectorsRated sectors }
                }

        Snapshot.NoLapYet ->
            lapBlock
                { label = "Last"
                , lapNumber = Nothing
                , time = Nothing
                , segments =
                    SegmentStrip.overSectors
                        { cells = Sector.initialize (\_ -> timeCell Nothing)
                        , strip = text ""
                        }
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
    , segments : Html msg
    }
    -> List (Html msg)
lapBlock { label, lapNumber, time, segments } =
    -- Two cells of the caller's grid rather than a grid of its own: which lap
    -- it is and what it took stand beside the sectors, a line of their own
    -- above them being a row of the panel's height spent on what fits in the
    -- margin of the row under it.
    --
    -- `text-right` reaches the time and not the line above it, which is a flex
    -- row and lays its own out: the label stays against the left edge the
    -- other lap's label is on, and the times end together where the sectors
    -- begin.
    [ div [ class "grid gap-y-0.5 text-right" ]
        [ div [ class "flex items-baseline gap-x-1.5" ]
            [ rowLabel label
            , div [ class "text-[10px] text-muted-foreground tabular-nums" ]
                [ text (lapNumber |> Maybe.map (\number -> "L" ++ String.fromInt number) |> Maybe.withDefault "") ]
            ]
        , timeText "text-[14px]" time
        ]
    , segments
    ]


{-| A sector of the lap under way, as how far off the best the car has driven it
in it was -- which is what there is to say about a sector while the lap it
belongs to is still being driven. What it took is on the strip below it, and the
lap beside it is where the times are read.
-}
deltaCell : Maybe Duration -> Maybe RatedTime -> Html msg
deltaCell best rated =
    div [ class "grid justify-items-center min-w-0" ]
        [ ratedText "text-[12px]" rated (deltaOf best rated) ]


{-| A sector of the lap behind, as the time it took.
-}
timeCell : Maybe RatedTime -> Html msg
timeCell rated =
    div [ class "grid justify-items-center min-w-0" ]
        [ timeText "text-[12px]" rated ]


{-| How the sector compares with the best the car has driven it in.

The best is taken over the laps the car has finished. The lap in progress is not
one of them, so a sector quicker than anything before it comes out negative; the
lap behind it is one of them, so its best sector comes out at nothing at all --
which is the reading, and the two columns are measured against the same thing.

-}
deltaOf : Maybe Duration -> Maybe RatedTime -> Maybe String
deltaOf best rated =
    Maybe.map2
        (\baseline time ->
            let
                delta =
                    time - baseline
            in
            if delta > 0 then
                "+" ++ Duration.toString delta

            else
                Duration.toString delta
        )
        best
        (Maybe.map .time rated)


timeText : String -> Maybe RatedTime -> Html msg
timeText size rated =
    ratedText size rated (rated |> Maybe.map (.time >> Duration.toString))


{-| A reading of a rated time -- the time itself, or how it stood against
something -- in the colour that rating paints it.
-}
ratedText : String -> Maybe RatedTime -> Maybe String -> Html msg
ratedText size rated reading =
    div
        [ class (size ++ " tabular-nums")
        , style "color" (rated |> Maybe.map (.performance >> Performance.toColorVariable) |> Maybe.withDefault "inherit")
        ]
        [ text (Maybe.withDefault "-" reading) ]


rowLabel : String -> Html msg
rowLabel label =
    div [ class "text-[9px] uppercase tracking-[0.03em] text-muted-foreground" ]
        [ text label ]
