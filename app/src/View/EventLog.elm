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
import Html.Attributes exposing (class)
import List.Extra
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Flag as Flag
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
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


{-| One line of the Log: the moment, what to say about it, and what the
car's name or handover appends.
-}
type alias Line =
    { at : Instant
    , label : String
    , detail : Maybe String
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
                    ++ List.filterMap pitLine laps
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


lineRow : Line -> Html msg
lineRow line =
    div [ class "grid grid-cols-[1fr_auto] gap-x-2 items-baseline py-0.5" ]
        [ div [ class "truncate" ]
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
