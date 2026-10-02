module Motorsport.Analysis.CarLog exposing (Line, Kind(..), lines)

{-| One car's race, as the list of what has happened to it: the events the field
announced, the stops it made, and the laps that improved its own best.

The events come off [`Timeline`](Motorsport-Race-Timeline) and the stops and the
bests off the car's laps, which are handed over whole with the clock beside them
rather than cut: an event is read against the lap it fell on, and that lap is one
the car ran whatever the clock has reached. The clock cuts the lines and not the
laps.

A line says what happened, which lap it fell on, and how the time it names rates
against the records. How any of that is drawn belongs to the panel reading it.

@docs Line, Kind(..), lines

-}

import Motorsport.Driver as Driver
import Motorsport.Duration as Duration
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Lap.Performance as Performance exposing (PerformanceLevel)
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Race.Timeline as Timeline exposing (Timeline)
import Motorsport.Race.TimelineEvent as TimelineEvent exposing (CarEventType(..), EventType(..), TimelineEvent)


{-| One line of the Log: the moment, the lap the line is about, what to say about
it, whose lap that time was, and the rating that colours it.

`lap` is the lap the line is about: the one the moment fell on for a stop and for
an announcement, and the one that ran to the time for a best or a record.
`Nothing` where the car had turned no lap yet, which is where the race's own start
stands.

`by` is the driver whose lap the label's time was, which is only a lap time has.

`kind` is which of the car's own doings the line is told from: a stop it made,
a lap that improved its best, or an announcement the field made about it.

-}
type alias Line =
    { at : Instant
    , lap : Maybe Int
    , label : String
    , by : Maybe String
    , level : PerformanceLevel
    , kind : Kind
    }


{-| Which of the car's own doings a line is told from.

A stop is told from the lap the car crossed into the lane on, but recorded on
the lap it came back out on — where its lane time sits. The two laps are a
stint apart.

-}
type Kind
    = Stop
    | Best
    | Announcement


{-| What has happened to the car by the clock, newest first.

Where two lines share a moment the event is told first: the sort is stable, and
the events go in ahead of the stops and the bests.

-}
lines : { elapsed : Instant } -> Car -> Timeline -> List Line
lines clock car timeline =
    let
        events =
            eventsOf clock.elapsed car.metadata.carNumber timeline

        records =
            recordTimes events

        bests =
            List.filterMap (personalBestLine records) car.laps
    in
    List.sortWith laterFirst
        (List.map (eventLine car) (List.filter (toldByOwnBest bests >> not) events)
            ++ List.filterMap (stopLine car.laps) car.laps
            ++ bests
        )
        |> List.filter (\line -> Instant.compare line.at clock.elapsed /= GT)


{-| The moments the feed announced one of the car's laps as the race's record.

A lap is rated as a record at the moment it took one, not at the moment the clock
stands on: a line about lap 14 reads as the record lap 14 took, whether or not a
later lap beat it.

-}
recordTimes : List TimelineEvent -> List Instant
recordTimes events =
    events
        |> List.filter
            (\event ->
                case event.eventType of
                    CarEvent _ FastestLap ->
                        True

                    _ ->
                        False
            )
        |> List.map .elapsed


{-| Whether the car's own laps tell the event: the lap that took the race's record
improved the car's best as well, so the feed's event and that lap's line name one
instant and one time, and the lap's line is the one kept.
-}
toldByOwnBest : List Line -> TimelineEvent -> Bool
toldByOwnBest bests event =
    case event.eventType of
        CarEvent _ FastestLap ->
            List.any (\best -> Instant.compare best.at event.elapsed == EQ) bests

        _ ->
            False


laterFirst : Line -> Line -> Order
laterFirst a b =
    Instant.compare b.at a.at


{-| The car's own events, newest first, of all those the field had by the clock.
-}
eventsOf : Instant -> CarNumber -> Timeline -> List TimelineEvent
eventsOf elapsed carNumber timeline =
    let
        upTo =
            Timeline.countUpTo elapsed timeline
    in
    Timeline.latest { upTo = upTo, limit = upTo } timeline
        |> List.filter (TimelineEvent.forCar carNumber << .eventType)


eventLine : Car -> TimelineEvent -> Line
eventLine car event =
    case ( event.eventType, TimelineEvent.runningLap car event ) of
        ( CarEvent _ DriverChange, _ ) ->
            case TimelineEvent.handover car event of
                Just ( handedOver, tookOver ) ->
                    { at = event.elapsed
                    , lap = lapNumber car event
                    , label = Driver.toHandover handedOver tookOver
                    , by = Nothing
                    , level = Performance.Standard
                    , kind = Announcement
                    }

                Nothing ->
                    plainLine car event

        ( CarEvent _ FastestLap, Just lap ) ->
            case lap.time of
                Just time ->
                    { at = event.elapsed
                    , lap = Just lap.lap
                    , label = Duration.toString time
                    , by = Just (Driver.toInitialAndSurname lap.driver)
                    , level = Performance.Fastest
                    , kind = Announcement
                    }

                Nothing ->
                    plainLine car event

        _ ->
            plainLine car event


{-| The lap the line is about: the one the event arrived on.
-}
lapNumber : Car -> TimelineEvent -> Maybe Int
lapNumber car event =
    TimelineEvent.runningLap car event
        |> Maybe.map .lap


plainLine : Car -> TimelineEvent -> Line
plainLine car event =
    { at = event.elapsed
    , lap = lapNumber car event
    , label = TimelineEvent.describe event.eventType
    , by = Nothing
    , level = Performance.Standard
    , kind = Announcement
    }


{-| The stop whose out-lap the lap carried: said as the lap the car entered the
lane on.

A stop the car never came out of has no lane time to say, and is the `Retired`
event's to tell.

-}
stopLine : List Lap -> Lap -> Maybe Line
stopLine allLaps lap =
    Lap.pitStopOf lap
        |> Maybe.map
            (\stop ->
                { at = stop.enteredAt
                , lap = Just (enteredOn allLaps lap stop.enteredAt)
                , label = "Pit"
                , by = Nothing
                , level = Performance.Standard
                , kind = Stop
                }
            )


{-| The lap that ended where the lane was entered: the crossing into the lane is
the previous lap's finish line, which is the lap the crossing itself completes.
Where no lap had been completed yet, the lap number the stop sits behind is the
best the laps can say.
-}
enteredOn : List Lap -> Lap -> Instant -> Int
enteredOn allLaps pitLap crossedIn =
    Lap.findLastLapAt { elapsed = crossedIn } allLaps
        |> Maybe.map .lap
        |> Maybe.withDefault (pitLap.lap - 1)


{-| The laps that improved the car's own best. The feed carries the best running
to and including each lap, so a lap whose time is its `best` is one that improved
it.

A lap that took the race's record makes a line here and no event's line: it
improved the car's best on the way to taking the record, and the record is left to
this line, rated as the record.

-}
personalBestLine : List Instant -> Lap -> Maybe Line
personalBestLine records lap =
    case ( lap.time, lap.best ) of
        ( Just time, Just best ) ->
            if time == best then
                Just
                    { at = lap.elapsed
                    , lap = Just lap.lap
                    , label = Duration.toString time
                    , by = Just (Driver.toInitialAndSurname lap.driver)
                    , level =
                        if List.any (\record -> Instant.compare record lap.elapsed == EQ) records then
                            Performance.Fastest

                        else
                            Performance.PersonalBest
                    , kind = Best
                    }

            else
                Nothing

        _ ->
            Nothing
