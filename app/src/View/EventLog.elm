module View.EventLog exposing (Occurred, rows)

{-| What the timeline and the laps say about one car, which is the Log section
of a car detail panel.

What an event is called, which of them a panel shows, and which lap one fell on
are `Motorsport.Race.TimelineEvent`'s, which the field's own timeline panel
reads too. Which lines a car's Log is made of is this module's own, and they say
more than the field's panel does.

@docs Occurred, rows

-}

import Html exposing (Html, div, span, text)
import Html.Attributes exposing (class, style)
import List.Extra
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Lap.Performance as Performance
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Race.Timeline as Timeline exposing (Timeline)
import Motorsport.Race.TimelineEvent as TimelineEvent exposing (CarEventType(..), TimelineEvent)
import UI.EmptyState as EmptyState


{-| One line of the Log: the moment, the lap number it falls on, what to say
about it, the driver its time belongs to, and the performance rating that
colours it.
-}
type alias Line =
    { at : Instant
    , lap : Int
    , label : String
    , by : Maybe String
    , level : Performance.PerformanceLevel
    }


{-| How much of the race the Log may speak of: how many events the field has
had, and how far the clock has run.
-}
type alias Occurred =
    { count : Int, elapsed : Duration }


{-| Everything that has happened to one car by the clock, newest first, at most
`recentLimit` lines: the timeline's events, its stops, and the laps that
improved its own best.
-}
rows : List Car -> Timeline -> Occurred -> CarNumber -> Html msg
rows cars timeline occurred carNumber =
    let
        car =
            List.Extra.find (\item -> item.metadata.carNumber == carNumber) cars

        laps =
            car |> Maybe.map .laps |> Maybe.withDefault []

        lines =
            List.sortWith laterFirst
                (List.map (timelineLine car) (eventsOf carNumber { upTo = occurred.count, limit = recentLimit } timeline)
                    ++ List.filterMap (pitLine laps) laps
                    ++ List.filterMap personalBestLine laps
                )
                |> List.filter (\line -> Instant.toDuration line.at <= occurred.elapsed)
                |> List.take recentLimit
    in
    if List.isEmpty lines then
        EmptyState.view "Nothing has happened to this car yet"

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
        |> List.filter (TimelineEvent.forCar carNumber << .eventType)
        |> List.take limit


recentLimit : Int
recentLimit =
    100


timelineLine : Maybe Car -> TimelineEvent -> Line
timelineLine car event =
    case ( event.eventType, TimelineEvent.runningLap car event ) of
        ( CarEvent _ DriverChange, _ ) ->
            case TimelineEvent.handover car event of
                Just ( handedOver, tookOver ) ->
                    { at = event.elapsed
                    , lap = lapNumber car event
                    , label = Driver.toHandover handedOver tookOver
                    , by = Nothing
                    , level = Performance.Standard
                    }

                Nothing ->
                    plainLine car event

        ( CarEvent _ FastestLap, Just lap ) ->
            case lap.time of
                Just time ->
                    { at = event.elapsed
                    , lap = lap.lap
                    , label = Duration.toString time
                    , by = Just (Driver.toInitialAndSurname lap.driver)
                    , level = Performance.Fastest
                    }

                Nothing ->
                    plainLine car event

        _ ->
            plainLine car event


{-| The lap running when the event arrived: the last one already completed.
-}
lapNumber : Maybe Car -> TimelineEvent -> Int
lapNumber car event =
    car
        |> TimelineEvent.runningLap event
        |> Maybe.map .lap
        |> Maybe.withDefault 0


plainLine : Maybe Car -> TimelineEvent -> Line
plainLine car event =
    { at = event.elapsed
    , lap = lapNumber car event
    , label = TimelineEvent.describe event.eventType
    , by = Nothing
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
                , by = Nothing
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
                    , by = Just (Driver.toInitialAndSurname lap.driver)
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
            , case line.by of
                Just second ->
                    span [ class "text-muted-foreground" ] [ text (" · " ++ second) ]

                Nothing ->
                    text ""
            ]
        , div [ class "tabular-nums text-muted-foreground" ]
            [ text (line.at |> Instant.toDuration |> Duration.toStringToSeconds) ]
        ]
