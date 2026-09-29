module View.EventLog exposing (describe, detail, rows)

{-| What the timeline says, spelled in one place for the two panels that say it:
the field's own, which draws every event of the race, and the Log section of a
car detail panel, which draws one car's. The wording is shared so the two can
never disagree about what happened.

@docs describe, detail, rows

-}

import Dict exposing (Dict)
import Html exposing (Html, div, text)
import Html.Attributes exposing (class)
import Html.Lazy
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Flag as Flag
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap
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


{-| The second line an event has, read off the car's laps at the event.

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


{-| The events of one car that have happened, newest first, at most
`recentLimit` of them.

`upTo` is a count of the race's events rather than a moment, the number
`Timeline.countUpTo` hands out, so a caller can hold it for as long as no event
has arrived -- which is what lets the rows be built behind a lazy thunk.
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


{-| The Log section's rows. The cars, the timeline and the count never move
under playback, and the count is a number, so the rows are rebuilt only when an
event arrives -- anything frame-made passed instead is a fresh reference on
every frame and misses.
-}
rows : List Car -> Timeline -> Int -> CarNumber -> Html msg
rows cars timeline occurredCount carNumber =
    Html.Lazy.lazy4 lazyRows cars timeline occurredCount carNumber


lazyRows : List Car -> Timeline -> Int -> CarNumber -> Html msg
lazyRows cars timeline occurredCount carNumber =
    let
        carsByNumber =
            cars
                |> List.map (\car -> ( car.metadata.carNumber, car ))
                |> Dict.fromList

        events =
            eventsOf carNumber { upTo = occurredCount, limit = recentLimit } timeline
    in
    if List.isEmpty events then
        div [ class "p-5 text-center italic text-muted-foreground" ]
            [ text "Nothing has happened to this car yet" ]

    else
        div [ class "grid gap-y-px text-xs" ]
            (List.map (logRow carsByNumber) events)


logRow : Dict CarNumber Car -> TimelineEvent -> Html msg
logRow carsByNumber event =
    let
        car =
            case event.eventType of
                CarEvent carNumber _ ->
                    Dict.get carNumber carsByNumber

                _ ->
                    Nothing
    in
    div [ class "grid grid-cols-[1fr_auto] gap-x-2 items-baseline py-0.5" ]
        [ div []
            [ text (describe event.eventType)
            , case detail car event of
                Just line ->
                    div [ class "text-[10px] text-muted-foreground whitespace-nowrap" ] [ text line ]

                Nothing ->
                    text ""
            ]
        , div [ class "tabular-nums text-muted-foreground" ]
            [ text (event.elapsed |> Instant.toDuration |> Duration.toStringToSeconds) ]
        ]
