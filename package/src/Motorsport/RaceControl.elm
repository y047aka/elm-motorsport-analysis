module Motorsport.RaceControl exposing (Model, Msg(..), applyEvents, applyLiveUpdate, fromCars, placeholder, update)

import List.Extra
import List.NonEmpty as NonEmpty exposing (NonEmpty)
import Motorsport.Car as Car exposing (Car, Status(..))
import Motorsport.Class as Class
import Motorsport.Clock as Clock exposing (Model(..))
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap
import Motorsport.LiveTiming exposing (LiveUpdateData, CarUpdate)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.TimelineEvent as TimelineEvent exposing (EventType(..), TimelineEvent)
import Time exposing (Posix, millisToPosix)



-- MODEL


type alias Model =
    { clock : Clock.Model
    , lapCount : Int
    , lapTotal : Int
    , timeLimit : Int
    , cars : NonEmpty Car
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
    init [] (NonEmpty.singleton dummyCar)


fromCars : List TimelineEvent -> List Car -> Maybe Model
fromCars timelineEvents cars =
    NonEmpty.fromList cars |> Maybe.map (init timelineEvents)


init : List TimelineEvent -> NonEmpty Car -> Model
init timelineEvents cars =
    let
        carsList =
            NonEmpty.toList cars

        timeLimit =
            calcTimeLimit carsList
    in
    { clock = Initial
    , lapCount = 0
    , lapTotal = calcLapTotal cars
    , timeLimit = timeLimit
    , cars = cars
    , timelineEvents = timelineEvents
    }


calcLapTotal : NonEmpty Car -> Int
calcLapTotal =
    NonEmpty.map (.laps >> List.length)
        >> NonEmpty.maximum


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
    | Add10seconds
    | SetCount Int
    | NextLap
    | PreviousLap
    | ApplyLiveUpdate LiveUpdateData


update : Msg -> Model -> Model
update msg m =
    case msg of
        Start now ->
            { m | clock = Clock.update now Clock.Start m.clock }

        Tick now ->
            case m.clock of
                Started splitTime { startedAt } ->
                    if Clock.calcElapsed startedAt now splitTime < m.timeLimit then
                        let
                            newElapsed =
                                Clock.calcElapsed startedAt now splitTime

                            newClock =
                                { lapCount = lapAt newElapsed (NonEmpty.map .laps m.cars)
                                , elapsed = newElapsed
                                }
                        in
                        { m
                            | clock = Clock.update now Clock.Tick m.clock
                            , lapCount = newClock.lapCount
                            , cars =
                                m.cars
                                    |> applyEvents newElapsed m.timelineEvents
                                    |> NonEmpty.sortWith
                                        (\a b ->
                                            Maybe.map2 (Lap.compareAt { elapsed = newClock.elapsed }) a.currentLap b.currentLap
                                                |> Maybe.withDefault EQ
                                        )
                        }

                    else
                        m

                _ ->
                    m

        Pause now ->
            { m | clock = Clock.update now Clock.Pause m.clock }

        Finish now ->
            { m | clock = Clock.update now Clock.Finish m.clock }

        _ ->
            let
                dummyPosix =
                    millisToPosix 0

                { lapCount, elapsed } =
                    let
                        elapsed_ =
                            Clock.getElapsed m.clock

                        lapTimes =
                            NonEmpty.toList m.cars |> List.map .laps
                    in
                    case msg of
                        Add10seconds ->
                            if elapsed_ < m.timeLimit then
                                let
                                    newElapsed =
                                        elapsed_ + (10 * 1000)
                                in
                                { lapCount = lapAt newElapsed (NonEmpty.map .laps m.cars)
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
                        |> updateCars { elapsed = elapsed }
                        |> applyEvents elapsed m.timelineEvents
            }

        ApplyLiveUpdate liveData ->
            applyLiveUpdate liveData m


type alias Clock =
    { elapsed : Duration }


updateCars : Clock -> NonEmpty Car -> NonEmpty Car
updateCars raceClock cars =
    cars
        |> NonEmpty.map
            (\car ->
                let
                    currentLap =
                        Lap.findCurrentLap raceClock car.laps
                in
                { car
                    | currentLap = currentLap
                    , lastLap = Lap.findLastLapAt raceClock car.laps
                    , currentDriver = currentLap |> Maybe.map .driver
                }
            )
        |> NonEmpty.sortWith
            (\a b ->
                Maybe.map2 (Lap.compareAt raceClock) a.currentLap b.currentLap
                    |> Maybe.withDefault EQ
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
applyEvents : Duration -> List TimelineEvent -> NonEmpty Car -> NonEmpty Car
applyEvents currentElapsed events cars =
    let
        activeEvents =
            List.filter (\{ eventTime } -> (currentElapsed - 1000) < eventTime && eventTime <= currentElapsed) events

        ( carSpecificEvents, globalEvents ) =
            List.partition isCarEvent activeEvents
    in
    cars
        |> NonEmpty.map
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


lapAt : Int -> NonEmpty (List { a | lap : Int, elapsed : Duration }) -> Int
lapAt elapsed lapTimes =
    -- TODO: leaderのみを対象にする
    lapTimes
        |> NonEmpty.toList
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



-- LIVE UPDATE


{-| Apply live timing update to the race control model
-}
applyLiveUpdate : LiveUpdateData -> Model -> Model
applyLiveUpdate liveData model =
    let
        -- Append new timeline events
        updatedTimelineEvents =
            model.timelineEvents ++ liveData.newEvents

        -- Update cars with live data
        updatedCars =
            NonEmpty.map (applyCarUpdate liveData.updatedCars) model.cars
                |> applyEvents liveData.raceTime updatedTimelineEvents
                |> NonEmpty.sortWith
                    (\a b ->
                        Maybe.map2 (Lap.compareAt { elapsed = liveData.raceTime }) a.currentLap b.currentLap
                            |> Maybe.withDefault EQ
                    )

        -- Calculate new lap count
        newLapCount =
            lapAt liveData.raceTime (NonEmpty.map .laps updatedCars)
    in
    { model
        | cars = updatedCars
        | timelineEvents = updatedTimelineEvents
        | lapCount = newLapCount
    }


{-| Apply car update to a single car
-}
applyCarUpdate : List CarUpdate -> Car -> Car
applyCarUpdate updates car =
    case List.Extra.find (\u -> u.carNumber == car.metadata.carNumber) updates of
        Just update ->
            { car
                | currentLap =
                    case update.currentLap of
                        Just lap ->
                            Just lap

                        Nothing ->
                            car.currentLap
                , lastLap =
                    case update.lastCompletedLap of
                        Just lap ->
                            Just lap

                        Nothing ->
                            car.lastLap
            }

        Nothing ->
            car

