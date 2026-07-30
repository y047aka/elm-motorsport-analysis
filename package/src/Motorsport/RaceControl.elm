module Motorsport.RaceControl exposing (Model, Msg(..), fromEntrants, placeholder, update)

import List.Extra
import Motorsport.Car.StatusIndex as StatusIndex exposing (StatusIndex)
import Motorsport.Clock as Clock
import Motorsport.Duration exposing (Duration)
import Motorsport.Entrant exposing (Entrant)
import Motorsport.TimelineEvent exposing (TimelineEvent)
import Time exposing (Posix, millisToPosix)



-- MODEL


{-| The race, and where playback has got to in it.

Everything but `clock` and `lapCount` is settled when the race loads and never
moves again. What each car is doing at the current moment is not held here at
all: it is derived from an entrant and the clock, in the computed-model layer.
-}
type alias Model =
    { clock : Clock.Model
    , lapCount : Int
    , lapTotal : Int
    , timeLimit : Int
    , entrants : List Entrant
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
    , entrants = []
    , timelineEvents = []
    , statusIndex = StatusIndex.empty
    }


fromEntrants : List TimelineEvent -> List Entrant -> Model
fromEntrants timelineEvents entrants =
    { clock = Clock.init
    , lapCount = 0
    , lapTotal = calcLapTotal entrants
    , timeLimit = calcTimeLimit entrants
    , entrants = entrants
    , timelineEvents = timelineEvents
    , statusIndex = StatusIndex.fromTimelineEvents timelineEvents
    }


calcLapTotal : List Entrant -> Int
calcLapTotal entrants =
    entrants
        |> List.map (.laps >> List.length)
        |> List.maximum
        |> Maybe.withDefault 0


calcTimeLimit : List Entrant -> Duration
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
                            , lapCount = lapAt newElapsed (List.map .laps m.entrants)
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
                            List.map .laps m.entrants
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
            }


getCurrentTime : Clock.Model -> Posix
getCurrentTime clock =
    case clock.state of
        Clock.Started _ { now } ->
            now

        _ ->
            millisToPosix 0


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
