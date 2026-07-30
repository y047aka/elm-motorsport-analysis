module Motorsport.RaceControl exposing (Model, Msg(..), fromCars, placeholder, update)

import List.Extra
import Motorsport.Car exposing (Car)
import Motorsport.Car.StatusIndex as StatusIndex exposing (StatusIndex)
import Motorsport.Clock as Clock
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap
import Motorsport.TimelineEvent exposing (TimelineEvent)
import Time exposing (Posix, millisToPosix)



-- MODEL


{-| The cars are held in the order the race data arrived in, not in race order.
Who is ahead of whom is a reading of the clock, so it belongs to whoever is
looking -- see `Motorsport.Ordering.byRacePosition`.
-}
type alias Model =
    { clock : Clock.Model
    , lapCount : Int
    , lapTotal : Int
    , timeLimit : Int
    , cars : List Car
    , timelineEvents : List TimelineEvent
    , statusIndex : StatusIndex
    }


{-| A race with nothing in it, to hold the place of one that has not loaded yet.
-}
placeholder : Model
placeholder =
    { clock = Clock.init
    , lapCount = 0
    , lapTotal = 0
    , timeLimit = 0
    , cars = []
    , timelineEvents = []
    , statusIndex = StatusIndex.empty
    }


fromCars : List TimelineEvent -> List Car -> Model
fromCars timelineEvents cars =
    { clock = Clock.init
    , lapCount = 0
    , lapTotal = calcLapTotal cars
    , timeLimit = calcTimeLimit cars
    , cars = cars
    , timelineEvents = timelineEvents
    , statusIndex = StatusIndex.fromTimelineEvents timelineEvents
    }


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
                    let
                        newElapsed =
                            Clock.calcElapsed startedAt now splitTime m.clock.playbackSpeed
                    in
                    if newElapsed < m.timeLimit then
                        { m
                            | clock = Clock.update now Clock.Tick m.clock
                            , lapCount = lapAt newElapsed (List.map .laps m.cars)
                            , cars = carsAt { elapsed = newElapsed } m
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
                            List.map .laps m.cars
                    in
                    case msg of
                        SkipTime duration ->
                            if elapsed_ < m.timeLimit then
                                let
                                    newElapsed =
                                        elapsed_ + duration
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
                , cars = carsAt { elapsed = elapsed } m
            }


{-| Recompute every car against the clock: the lap it is on, the lap it has just
finished, and the status it holds at that moment.

Nothing here accumulates. The result is a function of the race data and the
elapsed time alone, so scrubbing backwards or jumping a whole hour lands on the
same cars that playing through would have.

-}
carsAt : { elapsed : Duration } -> Model -> List Car
carsAt clock m =
    m.cars
        |> updateCarFields clock
        |> StatusIndex.applyAt clock m.statusIndex


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
