module Motorsport.RaceControl exposing (CarEventType(..), Event, EventType(..), Model, Msg(..), applyEvents, calcEvents, fromCars, init, placeholder, update)

import List.Extra
import List.NonEmpty as NonEmpty exposing (NonEmpty)
import Motorsport.Car as Car exposing (Car, CarNumber, Status(..))
import Motorsport.Class as Class
import Motorsport.Clock as Clock exposing (Model(..))
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap
import Motorsport.Manufacturer as Manufacturer
import Time exposing (Posix, millisToPosix)



-- MODEL


type alias Model =
    { clock : Clock.Model
    , lapCount : Int
    , lapTotal : Int
    , timeLimit : Int
    , cars : NonEmpty Car
    , events : List Event
    }


type alias Event =
    { eventTime : Duration, eventType : EventType }


type EventType
    = RaceStart
    | CarEvent CarNumber CarEventType


type CarEventType
    = Retirement
    | Checkered
    | LapCompleted Int


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
    init (NonEmpty.singleton dummyCar)


fromCars : List Car -> Maybe Model
fromCars =
    NonEmpty.fromList >> Maybe.map init


init : NonEmpty Car -> Model
init cars =
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
    , events = calcEvents timeLimit carsList
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


{-| 車両から各種イベント時刻を事前計算する関数
-}
calcEvents : Duration -> List Car -> List Event
calcEvents timeLimit cars =
    let
        -- レーススタートイベント（1つのみ、全車両に適用）
        raceStartEvent =
            { eventTime = 0, eventType = RaceStart }

        -- 各車のラップ完了イベント
        lapCompletionEvents =
            cars
                |> List.concatMap
                    (\car ->
                        car.laps
                            |> List.map
                                (\lap ->
                                    { eventTime = lap.elapsed
                                    , eventType = CarEvent car.metadata.carNumber (LapCompleted lap.lap)
                                    }
                                )
                    )

        -- 既存のリタイア・チェッカーイベント
        finalEvents =
            cars
                |> List.filterMap
                    (\car ->
                        List.Extra.last car.laps
                            |> Maybe.map
                                (\finalLap ->
                                    -- 時間制限より前に終わった車両はリタイア、以降はチェッカー
                                    if finalLap.elapsed < timeLimit then
                                        { eventTime = finalLap.elapsed, eventType = CarEvent car.metadata.carNumber Retirement }

                                    else
                                        { eventTime = finalLap.elapsed, eventType = CarEvent car.metadata.carNumber Checkered }
                                )
                    )
    in
    (raceStartEvent :: (lapCompletionEvents ++ finalEvents))
        |> List.sortBy .eventTime



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
                                    |> applyEvents newElapsed m.events
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
                        |> applyEvents elapsed m.events
            }


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
                    , currentDriver = currentLap |> Maybe.map (\lap -> Driver lap.driver)
                }
            )
        |> NonEmpty.sortWith
            (\a b ->
                Maybe.map2 (Lap.compareAt raceClock) a.currentLap b.currentLap
                    |> Maybe.withDefault EQ
            )


{-| イベントが車両固有のイベントかどうかを判定する
-}
isCarEvent : Event -> Bool
isCarEvent { eventType } =
    case eventType of
        CarEvent _ _ ->
            True

        _ ->
            False


{-| イベント情報に基づいて車両のステータスを更新する
-}
applyEvents : Duration -> List Event -> NonEmpty Car -> NonEmpty Car
applyEvents currentElapsed events cars =
    let
        activeEvents =
            List.filter (\{ eventTime } -> (currentElapsed - 10000) < eventTime && eventTime <= currentElapsed) events

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
applyEventToCar : Event -> Car -> Car
applyEventToCar event car =
    case event.eventType of
        RaceStart ->
            { car
                | currentLap = List.head car.laps
                , status = Racing
            }

        CarEvent _ Retirement ->
            Car.setStatus Retired car

        CarEvent _ Checkered ->
            Car.setStatus Car.Checkered car

        CarEvent _ (LapCompleted lapNumber) ->
            { car
                | currentLap = List.Extra.find (\lap -> lap.lap == lapNumber + 1) car.laps
                , lastLap = List.Extra.find (\lap -> lap.lap == lapNumber) car.laps
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
