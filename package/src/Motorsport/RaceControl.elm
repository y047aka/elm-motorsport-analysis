module Motorsport.RaceControl exposing (Model, Msg(..), applyEvents, fromCars, fromTimeline, placeholder, update)

import List.Extra
import Motorsport.Car as Car exposing (Car, Status(..))
import Motorsport.LapExtractor as LapExtractor
import Motorsport.Class as Class
import Motorsport.Clock as Clock
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap
import Motorsport.Manufacturer as Manufacturer
import Motorsport.RunningOrder as RunningOrder exposing (RunningOrder)
import Motorsport.TimelineEvent as TimelineEvent exposing (EventType(..), TimelineEvent)
import Time exposing (Posix, millisToPosix)



-- MODEL


type alias Model =
    { clock : Clock.Model
    , lapCount : Int
    , lapTotal : Int
    , timeLimit : Int
    , cars : RunningOrder
    , timelineEvents : List TimelineEvent
    }


placeholder : Model
placeholder =
    let
        dummyCar =
            { metadata = { carNumber = "", drivers = [], class = Class.none, group = "", team = "", manufacturer = Manufacturer.Other }
            , startPosition = 0
            , laps = []
            , currentLap = Nothing
            , lastLap = Nothing
            , status = PreRace
            , currentDriver = Nothing
            }
    in
    { clock = Clock.init
    , lapCount = 0
    , lapTotal = 0
    , timeLimit = 0
    , cars = RunningOrder.singleton { elapsed = 0 } dummyCar
    , timelineEvents = []
    }


fromTimeline : List TimelineEvent -> List { position : Int, car : Car.Metadata } -> Maybe Model
fromTimeline timelineEvents startingGrid =
    startingGrid
        |> List.map Car.fromStartingGrid
        |> LapExtractor.extractLapsFromTimelineEvents timelineEvents
        |> fromCars timelineEvents


fromCars : List TimelineEvent -> List Car -> Maybe Model
fromCars timelineEvents cars =
    RunningOrder.fromList { elapsed = 0 } cars
        |> Maybe.map
            (\runningOrder ->
                { clock = Clock.init
                , lapCount = 0
                , lapTotal = calcLapTotal cars
                , timeLimit = calcTimeLimit cars
                , cars = runningOrder
                , timelineEvents = timelineEvents
                }
            )


calcLapTotal : List Car -> Int
calcLapTotal cars =
    cars
        |> List.map (.laps >> List.length)
        |> List.maximum
        |> Maybe.withDefault 0


calcTimeLimit : List Car -> Duration
calcTimeLimit =
    List.map (.laps >> List.Extra.last >> Maybe.map .elapsed)
        >> List.filterMap identity
        >> List.maximum
        >> Maybe.map (\timeLimit -> (timeLimit // (60 * 60 * 1000)) * 60 * 60 * 1000)
        >> Maybe.withDefault 0



-- UPDATE


type Msg
    = Start Posix
    | Pause Posix
    | Finish Posix
    | Tick Posix
    | SkipTime Duration
    | SetCount Int
    | NextLap
    | PreviousLap
    | SetPlaybackSpeed Clock.PlaybackSpeed


update : Msg -> Model -> Model
update msg m =
    case msg of
        Start now ->
            { m | clock = Clock.update now Clock.Start m.clock }

        Tick now ->
            case m.clock.state of
                Clock.Started splitTime { startedAt } ->
                    if Clock.calcElapsed startedAt now splitTime m.clock.playbackSpeed < m.timeLimit then
                        let
                            newElapsed =
                                Clock.calcElapsed startedAt now splitTime m.clock.playbackSpeed

                            newClock =
                                { lapCount = lapAt newElapsed (List.map .laps (RunningOrder.toList m.cars))
                                , elapsed = newElapsed
                                }
                        in
                        { m
                            | clock = Clock.update now Clock.Tick m.clock
                            , lapCount = newClock.lapCount
                            , cars =
                                m.cars
                                    |> RunningOrder.toList
                                    |> applyEvents newElapsed m.timelineEvents
                                                |> RunningOrder.fromList { elapsed = newClock.elapsed }
                                    |> Maybe.withDefault m.cars
                        }

                    else
                        m

                _ ->
                    m

        Pause now ->
            { m | clock = Clock.update now Clock.Pause m.clock }

        Finish now ->
            { m | clock = Clock.update now Clock.Finish m.clock }

        SetPlaybackSpeed speed ->
            { m | clock = Clock.update (getCurrentTime m.clock) (Clock.SetPlaybackSpeed speed) m.clock }

        _ ->
            let
                dummyPosix =
                    millisToPosix 0

                { lapCount, elapsed } =
                    let
                        elapsed_ =
                            Clock.getElapsed m.clock

                        lapTimes =
                            RunningOrder.toList m.cars |> List.map .laps
                    in
                    case msg of
                        SkipTime duration ->
                            if elapsed_ < m.timeLimit then
                                let
                                    newElapsed =
                                        elapsed_ + duration
                                in
                                { lapCount = lapAt newElapsed (List.map .laps (RunningOrder.toList m.cars))
                                , elapsed = newElapsed
                                }

                            else
                                { lapCount = m.lapCount
                                , elapsed = elapsed_
                                }

                        SetCount newCount ->
                            if newCount >= 0 && newCount <= m.lapTotal then
                                { lapCount = newCount
                                , elapsed = elapsedAt newCount lapTimes
                                }

                            else
                                { lapCount = m.lapCount
                                , elapsed = elapsed_
                                }

                        NextLap ->
                            if m.lapCount < m.lapTotal then
                                let
                                    newCount =
                                        m.lapCount + 1
                                in
                                { lapCount = newCount
                                , elapsed = elapsedAt newCount lapTimes
                                }

                            else
                                { lapCount = m.lapCount
                                , elapsed = elapsed_
                                }

                        PreviousLap ->
                            if m.lapCount > 0 then
                                let
                                    newCount =
                                        m.lapCount - 1
                                in
                                { lapCount = newCount
                                , elapsed = elapsedAt newCount lapTimes
                                }

                            else
                                { lapCount = m.lapCount
                                , elapsed = elapsed_
                                }

                        _ ->
                            { lapCount = 0, elapsed = 0 }
            in
            { m
                | clock = Clock.update dummyPosix (Clock.Set elapsed) m.clock
                , lapCount = lapCount
                , cars =
                    m.cars
                        |> RunningOrder.toList
                        |> updateCarFields { elapsed = elapsed }
                        |> applyEvents elapsed m.timelineEvents
                        -- fromList returns Nothing only if the list is empty.
                        -- toList always returns a non-empty list, so this branch is unreachable.
                        |> RunningOrder.fromList { elapsed = elapsed }
                        |> Maybe.withDefault m.cars
            }


getCurrentTime : Clock.Model -> Posix
getCurrentTime clock =
    case clock.state of
        Clock.Started _ { now } ->
            now

        _ ->
            millisToPosix 0


updateCarFields : { elapsed : Duration } -> List Car -> List Car
updateCarFields clock =
    List.map
        (\car ->
            let
                currentLap =
                    Lap.findCurrentLap clock car.laps
            in
            { car
                | currentLap = currentLap
                , lastLap = Lap.findLastLapAt clock car.laps
                , currentDriver = currentLap |> Maybe.map .driver
            }
        )


{-| イベントが車両固有のイベントかどうかを判定する
-}
isCarEvent : TimelineEvent -> Bool
isCarEvent { eventType } =
    case eventType of
        CarEvent _ _ ->
            True

        _ ->
            False


{-| イベント情報に基づいて車両のステータスを更新する
-}
applyEvents : Duration -> List TimelineEvent -> List Car -> List Car
applyEvents currentElapsed events cars =
    let
        activeEvents =
            List.filter (\{ eventTime } -> (currentElapsed - 1000) < eventTime && eventTime <= currentElapsed) events

        ( carSpecificEvents, globalEvents ) =
            List.partition isCarEvent activeEvents
    in
    cars
        |> List.map
            (\car ->
                let
                    carEvents =
                        carSpecificEvents
                            |> List.filter
                                (\event ->
                                    case event.eventType of
                                        CarEvent carNumber _ ->
                                            carNumber == car.metadata.carNumber

                                        _ ->
                                            False
                                )
                            |> List.sortBy .eventTime

                    allEvents =
                        globalEvents ++ carEvents
                in
                List.foldl applyEventToCar car allEvents
            )


{-| 単一のイベントを車両に適用する
-}
applyEventToCar : TimelineEvent -> Car -> Car
applyEventToCar event car =
    case event.eventType of
        RaceStart ->
            car

        CarEvent _ (TimelineEvent.Start { currentLap }) ->
            { car
                | currentLap = Just currentLap
                , currentDriver = Just currentLap.driver
                , status = Racing
            }

        CarEvent _ (TimelineEvent.PitIn { lapNumber, duration }) ->
            Car.setStatus InPit car

        CarEvent _ (TimelineEvent.PitOut { lapNumber, duration }) ->
            Car.setStatus Racing car

        CarEvent _ TimelineEvent.Retirement ->
            Car.setStatus Retired car

        CarEvent _ TimelineEvent.Checkered ->
            Car.setStatus Car.Checkered car

        CarEvent _ (TimelineEvent.LapCompleted lapNumber { nextLap }) ->
            let
                currentLap =
                    Just nextLap
            in
            { car
                | currentLap = currentLap
                , lastLap = List.Extra.find (\lap -> lap.lap == lapNumber) car.laps
                , currentDriver = currentLap |> Maybe.map .driver
            }


lapAt : Int -> List (List { a | lap : Int, elapsed : Duration }) -> Int
lapAt elapsed lapTimes =
    -- TODO: leaderのみを対象にする
    lapTimes
        |> List.filterMap
            (List.Extra.findMap
                (\lap ->
                    if lap.elapsed > elapsed then
                        Just (lap.lap - 1)

                    else
                        Nothing
                )
            )
        |> List.maximum
        |> Maybe.withDefault 0


elapsedAt : Int -> List (List { a | lap : Int, elapsed : Duration }) -> Duration
elapsedAt lapCount lapTimes =
    let
        nextLap =
            lapCount + 1
    in
    lapTimes
        |> List.filterMap
            (List.Extra.findMap
                (\{ lap, elapsed } ->
                    if nextLap == lap then
                        Just elapsed

                    else
                        Nothing
                )
            )
        |> List.minimum
        |> Maybe.map (\elapsed -> elapsed - 1)
        |> Maybe.withDefault 0
