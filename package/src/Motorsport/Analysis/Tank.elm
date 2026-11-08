module Motorsport.Analysis.Tank exposing
    ( Tank(..), Level, Reason(..), Table
    , tableOf, level
    )

{-| How much of its tank a car has left, read off the laps the timing feed timed.

A stop takes on fuel, and the regulations let every car in a class fill the same
tank, so the laps a class runs between stops say how far a full tank goes. The
class's window is the top of that distribution and not its middle -- the question is
how far a tank can go -- and a car's level is how many laps it has run of the one it
is on. The bar is that fraction.

The unit is the **pace lap**, both sides of the division: a lap run under a procedure
is not a lap of fuel burnt, so it neither drains the tank nor joins the pool the
window is read from. [`Lap.atRacePace`](Motorsport-Lap#atRacePace) is the predicate
on both sides, which is what keeps a car held behind a procedure from reading dry.

Nothing here knows a joule, a litre, or a car's mass. The level is a share of the
window the class runs on, and the number beside it is laps -- the unit the pit wall
counts in.

**The error is measured, and shown.** In a race run on fuel a class agrees with
itself to a lap: the 2025 Le Mans classes ran 9 to 12 laps between stops, and read
from the stops the race had taught so far the meter came within two laps of the next
stop on 93 to 96% of the laps -- and read dry on none of them while the car still had
three laps left. The 2025 Circuit of the Americas answers nothing, and says so: one
class ran 6 stopped runs clean against 55 that met a procedure, which is too few
runs to make a decile and too lopsided to read one from, and its other class 17
against 55. So the class's own disagreement is carried out as `band` and drawn as a
band, the pool answers nothing while procedures hold most of the class's runs, and
where the disagreement passes a quarter of the window the reading is
[`NotOnWindow`](#Reason) -- that race is not being run on a window, and a bar would
be a guess wearing the shape of a meter.

[`Strategy`](Motorsport-Analysis-Strategy) reads the same stops for its own question,
how many still stand in the race. Its cycle counts the lap into the pits and this
does not, a lap run coasting down the lane being no lap of the ground a tank is
measured over; that is the whole of the difference between the two, and `TankTest`
holds them within a lap of one another on a class that ran clean.

@docs Tank, Level, Reason, Table
@docs tableOf, level

-}

import Dict exposing (Dict)
import Internal.Statistics as Statistics
import Motorsport.Analysis.Stint as Stint
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Race.Stint as RaceStint exposing (Stint)
import Motorsport.Wec.Class as Class exposing (Class)


{-| Where a car stands on its tank.

`Running` and `Overrun` carry the same reading and differ by which side of the
window the car stands on. An overrun is not an empty tank: it is a car still out
past the lap a full tank should have reached, which is its own telling --
short-fuelling, or a stint its team means to stretch to the flag.

-}
type Tank
    = Running Level
    | Overrun Level
    | Unreadable Reason


{-| The reading, in laps.

`laps` is laps of tank left (`Running`) or laps run past the window (`Overrun`), and
never both. `fraction` is the share of the window left, held between 0 and 1 for the
bar to be drawn at. `band` is the class's own disagreement in laps -- the error this
meter can, and does, admit to.

-}
type alias Level =
    { laps : Int
    , window : Int
    , band : Int
    , fraction : Float
    }


{-| Why a car has no level.

`NoWindow` is the class not yet having stopped enough to have a window;
`NotOnWindow` is a class whose runs disagree by more than a quarter of their own top
decile, so the race is not being run on fuel; `NoRun` is a car that has yet to
complete a lap at pace.

-}
type Reason
    = NoWindow
    | NotOnWindow
    | NoRun


{-| Every car's level, and every class's window, taken once off a race.

Built as the round loads and looked a car up in on every frame. A window is held as
a series keyed by the lap each run ended on, because one read off the finished race
would answer the fifth lap from a distribution the race had not run yet -- and answer
it again every time the reader scrubs the clock back.

-}
type Table
    = Table
        { cars : Dict CarNumber CarTank
        , windows : Dict String (List WindowAt)
        }


type alias CarTank =
    { class : Class
    , gauges : List Gauge
    }


{-| How many pace laps the car had run on its run, at one of its own laps.

One entry per lap at pace, newest first, so a clock finds its reading at the front --
and a stop means no more than the next entry starting again at one.

-}
type alias Gauge =
    { lap : Int
    , used : Int
    }


{-| What the class's stopped runs said as of one of its laps.

`window` is `Nothing` where the pool had too few runs to read, or had been eaten by
procedures -- an answer of its own, recorded at its own lap, so that a clock is told
the class's latest word rather than the last time it happened to say something.

-}
type alias WindowAt =
    { lap : Int
    , window : Maybe Window
    }


{-| A class's window in laps, and the disagreement between its runs.
-}
type alias Window =
    { laps : Int
    , band : Int
    }


{-| One of a car's runs between stops, counted in pace laps.
-}
type alias Run =
    { endLap : Maybe Int
    , held : Bool
    , paceLaps : Int
    , gauges : List Gauge
    }


{-| Read the race once: each class's window at every lap its runs ended on, and
every car's laps against it.
-}
tableOf : List Car -> Table
tableOf cars =
    let
        runs =
            cars |> List.map (\car -> ( car, runsOf car ))

        readings =
            runs
                |> List.map
                    (\( car, carRuns ) ->
                        ( car.metadata.carNumber
                        , { class = car.metadata.class
                          , gauges = carRuns |> List.concatMap .gauges |> List.reverse
                          }
                        )
                    )
                |> Dict.fromList

        windows =
            cars
                |> List.foldl
                    (\car seen ->
                        Dict.insert (Class.toString car.metadata.class) car.metadata.class seen
                    )
                    Dict.empty
                |> Dict.map (\_ class -> windowsOf class runs)
    in
    Table { cars = readings, windows = windows }


{-| How many clean stopped runs a class must have before its top decile is a window
and not one long fuel run wearing the class's name. Below this the class gets no tank
rather than a false one.

`Strategy` sets the same bar for its own cycle.

-}
minRuns : Int
minRuns =
    10


{-| What the class's stopped runs have said so far, as the race adds them.
-}
type alias Pool =
    { lengths : List Int
    , clean : Int
    , held : Int
    , seen : List WindowAt
    }


{-| A class's window at every lap one of its runs ended on, newest first.

Each entry is read from the runs that had ended by then, which is all a clock may
honestly be told from.

The pool grows one run at a time, and every run leaves a word behind -- the window,
or that there is no window yet. Two things have to hold for the first: enough runs to
make a decile mean something, and at least as many of them run clean as eaten by a
procedure. A window read from the runs that happened to avoid a caution is a window
read from the shortest runs the race had, which is how a meter comes to read dry a
hundred laps before the tank does.

-}
windowsOf : Class -> List ( Car, List Run ) -> List WindowAt
windowsOf class runs =
    runs
        |> List.filter (\( car, _ ) -> car.metadata.class == class)
        |> List.concatMap (Tuple.second >> stopped)
        |> List.sortBy (Maybe.withDefault 0 << .endLap)
        |> List.foldl
            (\run pool ->
                let
                    soFar =
                        if run.held then
                            { pool | held = pool.held + 1 }

                        else
                            { pool
                                | lengths = insert run.paceLaps pool.lengths
                                , clean = pool.clean + 1
                            }
                in
                { soFar
                    | seen =
                        { lap = Maybe.withDefault 0 run.endLap
                        , window =
                            if readable soFar then
                                windowOf soFar.lengths

                            else
                                Nothing
                        }
                            :: soFar.seen
                }
            )
            { lengths = [], clean = 0, held = 0, seen = [] }
        |> .seen


{-| Does the pool say a window yet: enough runs run clean, and at least as many of
them as the procedures left unheld.
-}
readable : Pool -> Bool
readable pool =
    pool.clean >= minRuns && pool.clean >= pool.held


{-| The runs a window is read from: those that ended in a stop. A run still running
has no length yet, and a stop that never came says nothing about how far a tank goes.

`Run.held` decides whether a run joins the pool the window is read from; it joins
the count of what the race did to the class either way.

-}
stopped : List Run -> List Run
stopped runs =
    runs |> List.filter (\run -> run.endLap /= Nothing)


{-| What a sorted pool of run lengths says: the top decile as the window, and the
interquartile range as the disagreement between the class's cars.
-}
windowOf : List Int -> Maybe Window
windowOf lengths =
    if List.length lengths >= minRuns then
        Statistics.quantile 0.9 lengths
            |> Maybe.andThen
                (\laps ->
                    Maybe.map2
                        (\lower upper -> { laps = laps, band = upper - lower })
                        (Statistics.quantile 0.25 lengths)
                        (Statistics.quantile 0.75 lengths)
                )

    else
        Nothing


{-| A car's runs, in order, each with its pace laps counted one lap at a time.

The runs themselves are [`Race.Stint`](Motorsport-Race-Stint)'s, which is where a run
between stops is decided; what is added here is the count of the laps among them that
burnt the tank.

-}
runsOf : Car -> List Run
runsOf car =
    car.laps
        |> Stint.summarize
        |> .stints
        |> List.map (runOf car.laps)


runOf : List Lap -> Stint -> Run
runOf laps stint =
    let
        paced =
            laps
                |> List.filter (\lap -> lap.lap >= stint.firstLap && lap.lap <= stint.lastLap)
                |> List.filter Lap.atRacePace

        endLap =
            case stint.end of
                RaceStint.Ended _ ->
                    Just stint.lastLap

                _ ->
                    Nothing
    in
    { endLap = endLap
    , held = stint.heldLaps > 0
    , paceLaps = List.length paced
    , gauges = List.indexedMap (\i lap -> { lap = lap.lap, used = i + 1 }) paced
    }


{-| Where a car stands on its tank at the clock.

`Nothing` is a car this race's field does not hold, which is not the same fact as a
car it does hold and has nothing to say about.

The class's own facts answer first: a class that has not stopped enough, or whose
runs agree on nothing, answers for every car in it alike.

-}
level : CarNumber -> Int -> Table -> Maybe Tank
level carNumber clock table =
    let
        (Table t) =
            table
    in
    Dict.get carNumber t.cars
        |> Maybe.map
            (\car ->
                case classWindow t.windows clock car.class of
                    Nothing ->
                        Unreadable NoWindow

                    Just found ->
                        if bandTooWide found then
                            Unreadable NotOnWindow

                        else
                            case atOrBefore .lap clock car.gauges of
                                Nothing ->
                                    Unreadable NoRun

                                Just gauge ->
                                    reading found gauge
            )


{-| The class's window as it stood at the clock: the word its newest ended run left,
which is a window or is the class saying it has none.
-}
classWindow : Dict String (List WindowAt) -> Int -> Class -> Maybe Window
classWindow windows clock class =
    Dict.get (Class.toString class) windows
        |> Maybe.andThen (atOrBefore .lap clock)
        |> Maybe.andThen .window


{-| The reading itself: how much of the window the car has left, and which side of
it it stands on.
-}
reading : Window -> Gauge -> Tank
reading window gauge =
    let
        left =
            window.laps - gauge.used
    in
    if left < 0 then
        Overrun
            { laps = negate left
            , window = window.laps
            , band = window.band
            , fraction = 0
            }

    else
        Running
            { laps = left
            , window = window.laps
            , band = window.band
            , fraction = Basics.clamp 0 1 (toFloat left / toFloat window.laps)
            }


{-| The disagreement that says this race is not run on a window: a quarter of the
window itself.

A class that runs 10 to 12 laps disagrees by nothing, and its bar is worth a column's
width. A class that runs 10 to 30 is a class of teams choosing when to stop, and no
share of a tank is in that.

-}
bandTooWide : Window -> Bool
bandTooWide window =
    window.band * 4 > window.laps


{-| Keep a pool sorted as it grows, so every window is read from a pool that is
already in order.
-}
insert : Int -> List Int -> List Int
insert length sorted =
    case sorted of
        [] ->
            [ length ]

        first :: rest ->
            if length <= first then
                length :: sorted

            else
                first :: insert length rest


{-| The newest entry at or before the clock, out of a list kept newest first.
-}
atOrBefore : (entry -> Int) -> Int -> List entry -> Maybe entry
atOrBefore key clock entries =
    entries
        |> List.filter (\entry -> key entry <= clock)
        |> List.head
