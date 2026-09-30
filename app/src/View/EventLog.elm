module View.EventLog exposing (describe, rows)

{-| What the timeline and the laps say about one car, which is the Log section
of a car detail panel. The event names come from `describe`, which the field's
own timeline panel also reads, so the two never disagree about what an event is
called; the lines themselves are the Log's own, and say more than the field's
panel does.

@docs describe, rows

-}

import Dict exposing (Dict)
import Html exposing (Html, div, span, text)
import Html.Attributes exposing (class, style)
import List.Extra
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Flag as Flag
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Lap.Performance as Performance
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Race.Timeline as Timeline exposing (Timeline)
import Motorsport.Race.TimelineEvent exposing (CarEventType(..), EventType(..), TimelineEvent)


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


{-| What a timeline event's row appends after its name, read off the car's
laps at the event.

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


{-| One line of the Log: the moment, the lap number it falls on, what to say
about it, what the car's name or handover appends, and the performance rating
that colours it.
-}
type alias Line =
    { at : Instant
    , lap : Int
    , label : String
    , detail : Maybe String
    , level : Performance.PerformanceLevel
    }


{-| Everything that has happened to one car by `elapsed`, newest first, at most
`recentLimit` lines: the timeline's events, its stops, and the laps that
improved its own best.
-}
rows : List Car -> Timeline -> Int -> Duration -> CarNumber -> Html msg
rows cars timeline occurredCount elapsed carNumber =
    let
        car =
            List.Extra.find (\item -> item.metadata.carNumber == carNumber) cars

        laps =
            car |> Maybe.map .laps |> Maybe.withDefault []

        lines =
            List.sortWith laterFirst
                (List.map (timelineLine car) (eventsOf carNumber { upTo = occurredCount, limit = recentLimit } timeline)
                    ++ List.filterMap (pitLine laps) laps
                    ++ List.filterMap personalBestLine laps
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
        CarEvent _ LeaderInPit ->
            False

        CarEvent number _ ->
            number == carNumber

        _ ->
            False


recentLimit : Int
recentLimit =
    100


timelineLine : Maybe Car -> TimelineEvent -> Line
timelineLine car event =
    case ( event.eventType, timedLap car event ) of
        ( CarEvent _ DriverChange, _ ) ->
            case detail car event of
                Just handover ->
                    { at = event.elapsed, lap = lapNumber car event, label = handover, detail = Nothing, level = Performance.Standard }

                Nothing ->
                    plainLine car event

        ( CarEvent _ FastestLap, Just lap ) ->
            { at = event.elapsed
            , lap = lap.lap
            , label = Duration.toString lap.time
            , detail = Just (Driver.toInitialAndSurname lap.driver)
            , level = Performance.Fastest
            }

        _ ->
            plainLine car event


{-| The lap running when the event arrived: the last one already completed.
-}
lapNumber : Maybe Car -> TimelineEvent -> Int
lapNumber car event =
    car
        |> Maybe.andThen (\item -> Lap.findLastLapAt { elapsed = event.elapsed } item.laps)
        |> Maybe.map .lap
        |> Maybe.withDefault 0


{-| The lap a fastest-lap event completes -- its number, its time and its
driver, which are what the event's own name and its colour then carry.
-}
timedLap : Maybe Car -> TimelineEvent -> Maybe { lap : Int, time : Duration, driver : Driver.Driver }
timedLap car event =
    car
        |> Maybe.andThen (\item -> Lap.findLastLapAt { elapsed = event.elapsed } item.laps)
        |> Maybe.andThen
            (\lap ->
                lap.time
                    |> Maybe.map (\time -> { lap = lap.lap, time = time, driver = lap.driver })
            )


plainLine : Maybe Car -> TimelineEvent -> Line
plainLine car event =
    { at = event.elapsed
    , lap = lapNumber car event
    , label = describe event.eventType
    , detail = detail car event
    , level = Performance.Standard
    }


{-| The stop whose out-lap the lap carried: said as the lap the car entered
the lane on.

A stop the car never came out of has no lane time to say, and is the
`Retired` event's to tell.

-}
pitLine : List Lap -> Lap -> Maybe Line
pitLine allLaps lap =
    case ( Lap.pitEntryAt lap, Lap.laneTimeOf lap ) of
        ( Just crossedIn, Just _ ) ->
            let
                entered =
                    enteredOn allLaps lap crossedIn
            in
            Just
                { at = crossedIn
                , lap = entered
                , label = "Pit"
                , detail = Nothing
                , level = Performance.Standard
                }

        _ ->
            Nothing


{-| The lap that ended where the lane was entered: the crossing into the lane
is the previous lap's finish line, so the lap number the entry falls on is
that lap's. Where no lap names the crossing, the lap number the stop sits
behind is the best the laps can say.
-}
enteredOn : List Lap -> Lap -> Instant -> Int
enteredOn allLaps pitLap crossedIn =
    allLaps
        |> List.Extra.find (\lap -> Instant.compare lap.elapsed crossedIn == EQ)
        |> Maybe.map .lap
        |> Maybe.withDefault (pitLap.lap - 1)


{-| The laps that improved the car's own best, in the colour a personal best
paints a time. The feed carries the best running to and including each lap, so
a lap whose time is its `best` is one that improved it.
-}
personalBestLine : Lap -> Maybe Line
personalBestLine lap =
    case ( lap.time, lap.best ) of
        ( Just time, Just best ) ->
            if time == best then
                Just
                    { at = lap.elapsed
                    , lap = lap.lap
                    , label = Duration.toString time
                    , detail = Just (Driver.toInitialAndSurname lap.driver)
                    , level = Performance.PersonalBest
                    }

            else
                Nothing

        _ ->
            Nothing


lineRow : Line -> Html msg
lineRow line =
    div [ class "grid grid-cols-[2rem_1fr_auto] gap-x-2 items-baseline py-0.5" ]
        [ div [ class "text-right tabular-nums text-muted-foreground" ]
            [ text (String.fromInt line.lap) ]
        , div [ class "truncate", style "color" (Performance.textColorOf line.level) ]
            [ text line.label
            , case line.detail of
                Just second ->
                    span [ class "text-muted-foreground" ] [ text (" · " ++ second) ]

                Nothing ->
                    text ""
            ]
        , div [ class "tabular-nums text-muted-foreground" ]
            [ text (line.at |> Instant.toDuration |> Duration.toStringToSeconds) ]
        ]
