module Motorsport.RaceControl exposing (CheckeredInfo, Model, Msg(..), RetirementInfo, empty, init, update, updateCars)

import List.Extra
import Motorsport.Car as Car exposing (Car)
import Motorsport.Clock as Clock exposing (Model(..))
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap
import Time exposing (Posix, millisToPosix)



-- MODEL


type alias Model =
    { clock : Clock.Model
    , lapCount : Int
    , lapTotal : Int
    , timeLimit : Int
    , cars : List Car
    , retirements : List RetirementInfo
    , checkered : List CheckeredInfo
    }


type alias RetirementInfo =
    { carNumber : String
    , retirementTime : Duration
    }


type alias CheckeredInfo =
    { carNumber : String
    , checkeredTime : Duration
    }


empty : Model
empty =
    { clock = Initial
    , lapCount = 0
    , lapTotal = 0
    , timeLimit = 0
    , cars = []
    , retirements = []
    , checkered = []
    }


init : List Car -> Model
init cars =
    let
        timeLimit =
            calcTimeLimit cars
    in
    { clock = Initial
    , lapCount = 0
    , lapTotal = calcLapTotal cars
    , timeLimit = timeLimit
    , cars = cars
    , retirements = calcRetirements timeLimit cars
    , checkered = calcCheckered timeLimit cars
    }


calcLapTotal : List Car -> Int
calcLapTotal =
    List.map (.laps >> List.length)
        >> List.maximum
        >> Maybe.withDefault 0


calcTimeLimit : List Car -> Duration
calcTimeLimit =
    List.map (.laps >> List.Extra.last >> Maybe.map .elapsed)
        >> List.filterMap identity
        >> List.maximum
        >> Maybe.map (\timeLimit -> (timeLimit // (60 * 60 * 1000)) * 60 * 60 * 1000)
        >> Maybe.withDefault 0


{-| 車両からリタイア時刻を事前計算する関数
-}
calcRetirements : Duration -> List Car -> List RetirementInfo
calcRetirements timeLimit cars =
    cars
        |> List.filterMap
            (\car ->
                List.Extra.last car.laps
                    |> Maybe.andThen
                        (\finalLap ->
                            -- 時間制限より前に最終ラップが終わった車両はリタイア
                            if finalLap.elapsed < timeLimit then
                                Just { carNumber = car.metaData.carNumber, retirementTime = finalLap.elapsed }

                            else
                                Nothing
                        )
            )


{-| 車両からチェッカー時刻を事前計算する関数
-}
calcCheckered : Duration -> List Car -> List CheckeredInfo
calcCheckered timeLimit cars =
    cars
        |> List.filterMap
            (\car ->
                List.Extra.last car.laps
                    |> Maybe.andThen
                        (\finalLap ->
                            -- 時間制限以降に最終ラップが終わった車両はチェッカー
                            if finalLap.elapsed >= timeLimit then
                                Just { carNumber = car.metaData.carNumber, checkeredTime = finalLap.elapsed }

                            else
                                Nothing
                        )
            )



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
                                { lapCount = lapAt newElapsed (List.map .laps m.cars)
                                , elapsed = newElapsed
                                }
                        in
                        { m
                            | clock = Clock.update now Clock.Tick m.clock
                            , lapCount = newClock.lapCount
                            , cars =
                                updateCars m.timeLimit { elapsed = newClock.elapsed } m.cars
                                    |> applyRetirements newElapsed m.retirements
                                    |> applyCheckered newElapsed m.checkered
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
                            List.map .laps m.cars
                    in
                    case msg of
                        Add10seconds ->
                            if elapsed_ < m.timeLimit then
                                let
                                    newElapsed =
                                        elapsed_ + (10 * 1000)
                                in
                                { lapCount = lapAt newElapsed lapTimes
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
                    updateCars m.timeLimit { elapsed = elapsed } m.cars
                        |> applyRetirements elapsed m.retirements
                        |> applyCheckered elapsed m.checkered
            }


type alias Clock =
    { elapsed : Duration }


updateCars : Duration -> Clock -> List Car -> List Car
updateCars timeLimit raceClock cars =
    cars
        |> List.map (Car.updateWithClock { elapsed = raceClock.elapsed, timeLimit = timeLimit })
        |> List.sortWith
            (\a b ->
                Maybe.map2 (Lap.compareAt raceClock) a.currentLap b.currentLap
                    |> Maybe.withDefault EQ
            )


{-| リタイア情報に基づいて車両のステータスをリタイアに設定する
-}
applyRetirements : Duration -> List RetirementInfo -> List Car -> List Car
applyRetirements currentElapsed retirements cars =
    cars
        |> List.map
            (\car ->
                case findRetirementByCarNumber car.metaData.carNumber retirements of
                    Just retirement ->
                        -- リタイア時刻に達した場合、ステータスをRetiredに変更
                        if currentElapsed >= retirement.retirementTime && car.status /= Car.Retired then
                            { car | status = Car.Retired }

                        else
                            car

                    Nothing ->
                        car
            )


{-| チェッカー情報に基づいて車両のステータスをチェッカーに設定する
-}
applyCheckered : Duration -> List CheckeredInfo -> List Car -> List Car
applyCheckered currentElapsed checkered cars =
    cars
        |> List.map
            (\car ->
                case findCheckeredByCarNumber car.metaData.carNumber checkered of
                    Just checkeredInfo ->
                        -- チェッカー時刻に達した場合、ステータスをCheckeredに変更
                        if currentElapsed >= checkeredInfo.checkeredTime && car.status /= Car.Checkered && car.status /= Car.Retired then
                            { car | status = Car.Checkered }

                        else
                            car

                    Nothing ->
                        car
            )


{-| 車両番号からリタイア情報を検索する
-}
findRetirementByCarNumber : String -> List RetirementInfo -> Maybe RetirementInfo
findRetirementByCarNumber carNumber retirements =
    List.Extra.find (\retirement -> retirement.carNumber == carNumber) retirements


{-| 車両番号からチェッカー情報を検索する
-}
findCheckeredByCarNumber : String -> List CheckeredInfo -> Maybe CheckeredInfo
findCheckeredByCarNumber carNumber checkered =
    List.Extra.find (\info -> info.carNumber == carNumber) checkered


lapAt : Int -> List (List { a | lap : Int, elapsed : Duration }) -> Int
lapAt elapsed lapTimes =
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
