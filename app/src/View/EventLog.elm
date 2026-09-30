module View.EventLog exposing (describe, rows)

{-| What the timeline and the laps say about one car, which is the Log section
of a car detail panel. The event names come from `describe`, which the field's
own timeline panel also reads, so the two never disagree about what an event is
called; the lines themselves are the Log's own, and say more than the field's
panel does.

@docs describe, rows

-}

import Dict exposing (Dict)
import Html exposing (Html, div, text)
import Html.Attributes exposing (class)
import List.Extra
import Motorsport.BestTimes as BestTimes
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Flag as Flag
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Race.Timeline as Timeline exposing (Timeline)
import Motorsport.Race.TimelineEvent exposing (CarEventType(..), EventType(..), TimelineEvent)
import Motorsport.Sector as Sector
import Motorsport.Wec.Circuit.LeMans as LeMans


{-| What happened, in the words both panels print.
-}
describe : EventType -> String
describe eventType =
    case eventType of
        RaceStart ->
            "Race Start"

        Flag flag ->
            Flag.toString flag

        CarEvent _ OvertakeForLead ->
            "Overtake for Lead"

        CarEvent _ LeaderInPit ->
            "Leader In Pit"

        CarEvent _ FastestLap ->
            "Fastest Lap"

        CarEvent _ DriverChange ->
            "Driver Change"

        CarEvent _ Retired ->
            "Retired"

        CarEvent _ Finished ->
            "Finished"


{-| The second line a timeline event has, read off the car's laps at the event.

A fastest lap is the lap the event completes, its time and its driver. A driver
change is who handed the car to whom: the driver of the lap the event completes,
and the one of the lap in progress from it, which is the lap the car's
`currentDriver` is read off from then on.

-}
detail : Maybe Car -> TimelineEvent -> Maybe String
detail car event =
    let
        lapOf find =
            car |> Maybe.andThen (.laps >> find { elapsed = event.elapsed })

        driverOf find =
            lapOf find |> Maybe.map (.driver >> Driver.toInitialAndSurname)
    in
    case event.eventType of
        CarEvent _ FastestLap ->
            lapOf Lap.findLastLapAt
                |> Maybe.andThen
                    (\lap ->
                        lap.time
                            |> Maybe.map (\time -> Duration.toString time ++ " · " ++ Driver.toInitialAndSurname lap.driver)
                    )

        CarEvent _ DriverChange ->
            Maybe.map2 (\handedOver tookOver -> handedOver ++ " → " ++ tookOver)
                (driverOf Lap.findLastLapAt)
                (driverOf Lap.findCurrentLap)

        _ ->
            Nothing


{-| One line of the Log: the moment, what to say about it, and the second line
a fastest lap or a handover carries.
-}
type alias Line =
    { at : Instant
    , label : String
    , detail : Maybe String
    }


{-| Everything that has happened to one car by `elapsed`, newest first, at most
`recentLimit` lines: the timeline's events, its stops, the laps that improved
its own best, and the race records its laps took.
-}
rows : List Car -> Timeline -> Int -> Duration -> CarNumber -> BestTimes.Changes -> Html msg
rows cars timeline occurredCount elapsed carNumber changes =
    let
        car =
            List.Extra.find (\item -> item.metadata.carNumber == carNumber) cars

        laps =
            car |> Maybe.map .laps |> Maybe.withDefault []

        lines =
            List.sortWith laterFirst
                (List.map (timelineLine car) (eventsOf carNumber { upTo = occurredCount, limit = recentLimit } timeline)
                    ++ List.filterMap pitLine laps
                    ++ List.filterMap personalBestLine laps
                    ++ List.filterMap recordLine (BestTimes.takenBy carNumber changes)
                )
                |> List.filter (\line -> Instant.toDuration line.at <= elapsed)
                |> List.take recentLimit
    in
    if List.isEmpty lines then
        div [ class "p-5 text-center italic text-muted-foreground" ]
            [ text "Nothing has happened to this car yet" ]

    else
        div [ class "grid gap-y-px text-xs" ]
            (List.map lineRow lines)


laterFirst : Line -> Line -> Order
laterFirst a b =
    Instant.compare b.at a.at


{-| The events of one car that have happened, newest first, at most `limit` of
them.

`upTo` is a count of the race's events rather than a moment, the number
`Timeline.countUpTo` hands out.

-}
eventsOf : CarNumber -> { upTo : Int, limit : Int } -> Timeline -> List TimelineEvent
eventsOf carNumber { upTo, limit } timeline =
    Timeline.latest { upTo = upTo, limit = upTo } timeline
        |> List.filter (\event -> belongsTo carNumber event.eventType)
        |> List.take limit


belongsTo : CarNumber -> EventType -> Bool
belongsTo carNumber eventType =
    case eventType of
        CarEvent number _ ->
            number == carNumber

        _ ->
            False


recentLimit : Int
recentLimit =
    100


timelineLine : Maybe Car -> TimelineEvent -> Line
timelineLine car event =
    { at = event.elapsed
    , label = describe event.eventType
    , detail = detail car event
    }


{-| The stop whose out-lap the lap carried: when the car crossed into the lane,
and how long the lane took.

A stop the car never came out of has no lane time to say, and is the
`Retired` event's to tell.

-}
pitLine : Lap -> Maybe Line
pitLine lap =
    case ( Lap.pitEntryAt lap, Lap.laneTimeOf lap ) of
        ( Just crossedIn, Just lane ) ->
            Just { at = crossedIn, label = Duration.toString lane ++ " (Pit)", detail = Nothing }

        _ ->
            Nothing


{-| The laps that improved the car's own best. The feed carries the best
running to and including each lap, so a lap whose time is its `best` is one
that improved it.
-}
personalBestLine : Lap -> Maybe Line
personalBestLine lap =
    case ( lap.time, lap.best ) of
        ( Just time, Just best ) ->
            if time == best then
                Just { at = lap.elapsed, label = Duration.toString time ++ " (Personal best)", detail = Just (Driver.toInitialAndSurname lap.driver) }

            else
                Nothing

        _ ->
            Nothing


{-| The race records this car's laps took. The lap-time record is the timeline's
to announce -- it has a `Fastest Lap` event of its own for each taking -- and
only the sector and mini-sector records, which no event announces, are the
Log's to say.
-}
recordLine : BestTimes.Taking -> Maybe Line
recordLine taking =
    case taking.record of
        BestTimes.FastestLap ->
            Nothing

        _ ->
            Just
                { at = taking.at
                , label = Duration.toString taking.holder.time ++ " (" ++ recordName taking.record ++ ")"
                , detail = Just (Driver.toInitialAndSurname taking.holder.driver)
                }


recordName : BestTimes.Record -> String
recordName record =
    case record of
        BestTimes.FastestLap ->
            "Fastest lap record"

        BestTimes.SectorRecord sector ->
            Sector.toString sector ++ " record"

        BestTimes.MiniSectorRecord mini ->
            LeMans.toString mini ++ " record"


lineRow : Line -> Html msg
lineRow line =
    div [ class "grid grid-cols-[1fr_auto] gap-x-2 items-baseline py-0.5" ]
        [ div []
            [ text line.label
            , case line.detail of
                Just second ->
                    div [ class "text-[10px] text-muted-foreground whitespace-nowrap" ] [ text second ]

                Nothing ->
                    text ""
            ]
        , div [ class "tabular-nums text-muted-foreground" ]
            [ text (line.at |> Instant.toDuration |> Duration.toStringToSeconds) ]
        ]
