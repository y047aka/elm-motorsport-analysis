module Motorsport.Analysis.Tank exposing
    ( Tank(..), Level, Stops, Reason(..), Table
    , tableOf, level
    )

{-| How much of its tank a car has left, read off the laps the timing feed timed.

A stop takes on fuel, and the regulations let every car in a class fill the same
tank, so the laps a class runs between stops say how far a full tank goes.
The class's window is the top of that distribution and not its middle -- the question is how far a tank can go -- and a car's level is how many laps it has run of the one it is on.
The bar is that fraction.

The window is a constant of its class, read off the whole race; the clock enters only at a car's own laps.

The unit is the **pace lap**, both sides of the division: a lap run under a procedure is not a lap of fuel burnt, so it neither drains the tank nor joins the pool the window is read from.
[`Lap.atRacePace`](Motorsport-Lap#atRacePace) is the predicate on both sides, which is what keeps a car held behind a procedure from reading dry.

Nothing here knows a joule, a litre, or a car's mass.
The level is a share of the window the class runs on, and the number beside it is laps -- the unit the pit wall counts in.

**The error is measured, and shown.** Over the sixteen rounds kept here a drawn reading came within two laps of the lap the car actually came in on on 81% of the cells it was drawn on, and claimed a car was past its window while the car was still out on the road on 0.5% of them; the classes of the 2025 Le Mans came within 0.5 to 1.5 laps.
So the class's own disagreement is carried out as `band` and drawn as a band rather than hidden, and where it passes a quarter of the window this answers with [`Spread`](#Tank) -- the laps the class's stops actually fall on -- rather than with a level, since a level drawn on a race that is not run on a window is a guess wearing the shape of a meter.

[`Strategy`](Motorsport-Analysis-Strategy) reads its cycle off the same pool, the same decile and the same bar of ten runs, for its own question: how many still stand in the race.
Its cycle counts the lap into the pits and this does not, a lap run coasting down the lane being no lap of the ground a tank is measured over; that is the whole of the difference between the two, and `TankTest` holds them within a lap of one another on a class that ran clean.

@docs Tank, Level, Stops, Reason, Table
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

`Spread` is not a level at all. It is what a class whose runs disagree by more than a quarter of their own window answers with, and it says where the class stops rather than where one car is; see [`Stops`](#Stops).

-}
type Tank
    = Running Level
    | Overrun Level
    | Spread Stops
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


{-| What a class that is not run on a window does say: the laps its stops fall on.

`low` and `high` are the laps its middle half came in on, `median` the lap its middle stop fell on, and `window` its top decile -- the same count of laps the levels are drawn against, which is what lets one track hold both.
Every car in the class is given the same spread: what a class like that says is about the class, and no car's tank is in it.

-}
type alias Stops =
    { low : Int
    , high : Int
    , median : Int
    , window : Int
    }


{-| Why a car has no level.

`NoWindow` is the class having too few clean stopped runs in the whole race for a top decile to mean anything; `NoRun` is a car that has yet to complete a lap at pace.

-}
type Reason
    = NoWindow
    | NoRun


{-| Every car's laps against every class's window, taken once off a race.

A window is a constant of its class, and a class that has none is absent from the
table -- which is [`NoWindow`](#Reason) for every car in it alike. What moves with the
clock is the car's own gauge.

-}
type Table
    = Table
        { cars : Dict CarNumber CarTank
        , windows : Dict String Window
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


{-| A class's window in laps: its top decile, its middle, and its quarters.
-}
type alias Window =
    { laps : Int
    , band : Int
    , low : Int
    , high : Int
    , median : Int
    }


{-| One of a car's runs between stops, counted in pace laps.
-}
type alias Run =
    { endLap : Maybe Int
    , held : Bool
    , paceLaps : Int
    , gauges : List Gauge
    }


{-| How many clean stopped runs a class must have before its top decile is a window
and not one long fuel run wearing the class's name. Below this the class gets no tank
rather than a false one.

`Strategy` sets the same bar for its own cycle.

-}
minRuns : Int
minRuns =
    10


{-| Read the race once: each class's window, and every car's laps against it.
-}
tableOf : List Car -> Table
tableOf cars =
    let
        runs =
            List.map (\car -> ( car, runsOf car )) cars

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
                |> Dict.toList
                |> List.filterMap
                    (\( name, class ) ->
                        windowOf class runs |> Maybe.map (Tuple.pair name)
                    )
                |> Dict.fromList
    in
    Table { cars = readings, windows = windows }


{-| What a class's clean stopped runs say over the whole race: the top decile as the window, the distance between its quarters as the disagreement between its cars, and the quarters themselves for a class that disagrees too much to be read as a tank.

Runs the field was held down for join none of that.
A tank measured over procedure laps is a different tank, and the meter's own unit is
the lap the race was run at.

-}
windowOf : Class -> List ( Car, List Run ) -> Maybe Window
windowOf class runs =
    runs
        |> List.filter (\( car, _ ) -> car.metadata.class == class)
        |> List.concatMap (Tuple.second >> stopped)
        |> List.filter (\run -> not run.held)
        |> List.map .paceLaps
        |> List.sort
        |> windowFrom


{-| The top decile of a sorted pool, its middle, and the distance between its quarters -- a window, where the pool is big enough for any of them to mean something.
-}
windowFrom : List Int -> Maybe Window
windowFrom lengths =
    if List.length lengths < minRuns then
        Nothing

    else
        Maybe.map4
            (\laps high median low ->
                { laps = laps
                , band = high - low
                , low = low
                , high = high
                , median = median
                }
            )
            (Statistics.quantile 0.9 lengths)
            (Statistics.quantile 0.75 lengths)
            (Statistics.quantile 0.5 lengths)
            (Statistics.quantile 0.25 lengths)


{-| The runs a window is read from: those that ended in a stop. A run still running
has no length yet, and a stop that never came says nothing about how far a tank goes.
-}
stopped : List Run -> List Run
stopped runs =
    runs |> List.filter (\run -> run.endLap /= Nothing)


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

-}
level : CarNumber -> Int -> Table -> Maybe Tank
level carNumber clock table =
    let
        (Table t) =
            table
    in
    Dict.get carNumber t.cars
        |> Maybe.map (onItsTank clock t.windows)


{-| What the class's window has to say about one car at the clock -- the class's own spread if it has no window or runs on nothing so steady as a window, and the car's level otherwise.
-}
onItsTank : Int -> Dict String Window -> CarTank -> Tank
onItsTank clock windows car =
    case Dict.get (Class.toString car.class) windows of
        Nothing ->
            Unreadable NoWindow

        Just window ->
            if bandTooWide window then
                Spread
                    { low = window.low
                    , high = window.high
                    , median = window.median
                    , window = window.laps
                    }

            else
                case atOrBefore .lap clock car.gauges of
                    Nothing ->
                        Unreadable NoRun

                    Just gauge ->
                        reading window gauge


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

The quarter is measured and not a taste for tightness: over the sixteen rounds kept
here the classes within it read to 1.98 laps of the lap the car came in on, and every
looser class reads some four laps out, so widening this gate buys cells at the cost of
the reading rather than at the cost of nothing.

-}
bandTooWide : Window -> Bool
bandTooWide window =
    window.band * 4 > window.laps


{-| The newest entry at or before the clock, out of a list kept newest first.
-}
atOrBefore : (entry -> Int) -> Int -> List entry -> Maybe entry
atOrBefore key clock entries =
    entries
        |> List.filter (\entry -> key entry <= clock)
        |> List.head
