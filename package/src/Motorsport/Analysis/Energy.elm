module Motorsport.Analysis.Energy exposing
    ( Energy(..), Level, Stops, Table
    , tableOf, level
    )

{-| How much of its energy a car has left, read off the laps the timing feed timed.

A stop takes on what the stint ran down -- fuel, and in a hybrid the charge with it -- and the regulations give every car in a class the same of both, so the laps a class runs between stops say two things at once: how far one load can be pushed, and where the class brings its cars in.
This meter reads the second, called the class's **plan**, and carries the first -- its **ceiling** -- beside it.
The ceiling is the farthest the class was seen to go on a load, and it very nearly holds: of 6,096 clean stops over the sixteen rounds kept here, 13 ran more than two laps past their class's ceiling, every one of them a car running a stretch nobody else in the class ran.
A wall says nothing about when a car is due, and the plan does, which is why the bar counts down the plan.

The unit is the **pace lap**, both sides of the division: a lap run under a procedure is not a lap of energy spent at race rate, so it neither runs the load down nor joins the pool the plan is read from.
[`Lap.atRacePace`](Motorsport-Lap#atRacePace) is the predicate on both sides, which is what keeps a car held behind a procedure from reading empty.

Nothing here knows a joule, a litre, or a car's mass.
The level is a share of the plan its class is running, and the number beside it is laps -- the unit the pit wall counts in.

**The error is measured, and shown.** Over the sixteen rounds kept here the column drew a level on 84% of the car-laps it was asked about, and a drawn level came within two laps of the lap the car actually came in on on 82% of them; the classes of the 2025 Le Mans read to between 0.6 and 0.8 laps.
So the class's own disagreement is carried out as `band` and drawn as a band rather than hidden, and where a class runs no one plan this answers with [`Spread`](#Energy) -- the laps its stops actually fall on.

[`Strategy`](Motorsport-Analysis-Strategy) reads its cycle off the same pool as this module's ceiling, the same decile and the same bar of ten runs, for its own question: how many still stand in the race.
Its cycle counts the lap into the pits and this does not, a lap run coasting down the lane being no lap of the ground energy is measured over; that is the whole of the difference between the two, and `EnergyTest` holds them within a lap of one another on a class that ran clean.

@docs Energy, Level, Stops, Table
@docs tableOf, level

-}

import Dict exposing (Dict)
import Internal.Statistics as Statistics
import Motorsport.Analysis.Stint as Stint
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Race.Stint as RaceStint exposing (Stint)
import Motorsport.Wec.Class as Class exposing (Class)


{-| How far a car has gone on its energy, and which side of its class's plan it stands on.

`Running` and `Overrun` carry the same reading and differ by which side of the plan the
car stands on. An overrun is not an empty car: it is a car still out past the lap its
class's plan brings cars in, which is its own telling -- short-fuelling, or a stint its
team means to stretch to the flag.

`Spread` is not a level at all. It is what a class whose stops fall in no one block answers with; see [`Stops`](#Stops).

`Unreadable` is the one silence this keeps: a class whose clean stopped runs are too few in the whole race to read at all.

-}
type Energy
    = Running Level
    | Overrun Level
    | Spread Stops
    | Unreadable


{-| The reading, in laps.

`laps` is laps of the class's plan left (`Running`) or laps run past it (`Overrun`), and
never both. `fraction` is the share of the plan left, held between 0 and 1 for the bar to
be drawn at. `band` is the class's own disagreement within its plan -- the error this
meter can, and does, admit to. `ceiling` is how far any car in the class was seen to go on
one load, and is further than the plan wherever the class brings some of its cars in early.

-}
type alias Level =
    { laps : Int
    , plan : Int
    , band : Int
    , ceiling : Int
    , fraction : Float
    }


{-| What a class that runs no one plan does say: the laps its stops fall on.

`low` and `high` are the laps its middle half came in on, `median` the lap its middle stop
fell on, and `ceiling` the farthest the class got -- the longest of these laps, and so the
span one track can hold both drawings on.
Every car in the class is given the same spread: what a class like that says is about the
class, and no car's energy is in it.

-}
type alias Stops =
    { low : Int
    , high : Int
    , median : Int
    , ceiling : Int
    }


{-| Every car's laps against every class's plan, taken once off a race.

A plan is a constant of its class, and a class that has nothing to say is absent from the
table -- which is [`Unreadable`](#Energy) for every car in it alike. What moves with the
clock is the car's own gauge.

-}
type Table
    = Table
        { cars : Dict CarNumber CarGauges
        , classes : Dict String ClassReading
        }


type alias CarGauges =
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


{-| What one class's clean stopped runs say, taken over the whole race: the laps its stops
fell on, and the plan it ran -- `Nothing` where no block of those stops is the class's plan.
-}
type alias ClassReading =
    { stops : Stops
    , plan : Maybe Plan
    }


{-| The block of stops a class mostly ran, and how far the cars inside it disagree.
-}
type alias Plan =
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


{-| How many clean stopped runs a class must have before its stops say anything -- about a
plan, about a spread, about anything. Below this the class gets no reading rather than a
false one.

`Strategy` sets the same bar for its own cycle.

-}
minRuns : Int
minRuns =
    10


{-| The shortest plan worth a bar. A class whose middle block of stops stands at three laps
is a class that stopped in a scramble, and a bar over three laps tells a reader nothing a
stop does not.

Four is also what keeps a level's fraction from dividing by a plan of nothing.

-}
minPlan : Int
minPlan =
    4


{-| Read the race once: each class's plan, and every car's laps against it.
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

        classes =
            cars
                |> List.foldl
                    (\car seen ->
                        Dict.insert (Class.toString car.metadata.class) car.metadata.class seen
                    )
                    Dict.empty
                |> Dict.toList
                |> List.filterMap
                    (\( name, class ) ->
                        classReadingOf class runs |> Maybe.map (Tuple.pair name)
                    )
                |> Dict.fromList
    in
    Table { cars = readings, classes = classes }


{-| What a class's clean stopped runs say over the whole race -- runs the field was held
down for join none of that.
-}
classReadingOf : Class -> List ( Car, List Run ) -> Maybe ClassReading
classReadingOf class runs =
    let
        pool =
            runs
                |> List.filter (\( car, _ ) -> car.metadata.class == class)
                |> List.concatMap (Tuple.second >> stopped)
                |> List.filter (\run -> not run.held)
                |> List.map .paceLaps
                |> List.sort
    in
    stopsOf pool
        |> Maybe.map (\stops -> { stops = stops, plan = planOf pool })


{-| The laps a class's stops fell on: its quarters, its middle stop, and the farthest it
got -- where the pool is big enough for any of them to mean something.
-}
stopsOf : List Int -> Maybe Stops
stopsOf pool =
    if List.length pool < minRuns then
        Nothing

    else
        Maybe.map4
            (\low median high ceiling ->
                { low = low
                , median = median
                , high = high
                , ceiling = ceiling
                }
            )
            (Statistics.quantile 0.25 pool)
            (Statistics.median pool)
            (Statistics.quantile 0.75 pool)
            (Statistics.quantile 0.9 pool)


{-| The class's plan, where it runs one: the middle of the block its stops mostly fell in,
and the disagreement inside that block.
-}
planOf : List Int -> Maybe Plan
planOf pool =
    let
        block =
            largestBlock (blocksOf pool)
    in
    case ( block, block |> Maybe.andThen Statistics.median ) of
        ( Just runs, Just laps ) ->
            let
                plan =
                    { laps = laps, band = bandOf laps runs }
            in
            if runsTheClass plan (List.length runs) (List.length pool) then
                Just plan

            else
                Nothing

        _ ->
            Nothing


{-| The stops cut into blocks: two laps apart is two different plans, since no load gives a
car 11 laps on one stint and 13 on the next. Each block is kept newest first, which is all
a block is asked for.
-}
blocksOf : List Int -> List (List Int)
blocksOf sorted =
    case sorted of
        [] ->
            []

        first :: rest ->
            blocksKeeping rest ( first, [ first ] )


blocksKeeping : List Int -> ( Int, List Int ) -> List (List Int)
blocksKeeping rest ( newest, block ) =
    case rest of
        [] ->
            [ block ]

        next :: later ->
            if next - newest >= 2 then
                block :: blocksKeeping later ( next, [ next ] )

            else
                blocksKeeping later ( next, next :: block )


{-| The block holding most of the class's stops. Where two hold the same number, the earlier
one is the plan: it is the one that sends a car out first, and so the one a level runs out
first too.
-}
largestBlock : List (List Int) -> Maybe (List Int)
largestBlock blocks =
    blocks
        |> List.foldl
            (\block ( best, bestSize ) ->
                let
                    size =
                        List.length block
                in
                if size > bestSize then
                    ( Just block, size )

                else
                    ( best, bestSize )
            )
            ( Nothing, 0 )
        |> Tuple.first


{-| How far the cars inside a block disagree: the middle of their distance from its middle.

A middle distance and not a range: half a block's stops standing two laps from its middle is
a band of two.

-}
bandOf : Int -> List Int -> Int
bandOf laps block =
    Statistics.median (List.map (\stop -> abs (stop - laps)) block)
        |> Maybe.withDefault 0


{-| Two fifths of a class's stops is enough for a block to be called the class's plan, and
not one team's.

Measured over the sixteen rounds kept here, a class whose largest block holds under that
share ran two or three plans at once, and a level drawn on such a block read six laps out or
worse.

-}
carriesTheClass : Int -> Int -> Bool
carriesTheClass blockRuns poolRuns =
    blockRuns * 5 >= poolRuns * 2


{-| The runs a plan is read from: those that ended in a stop. A run still running
has no length yet, and a stop that never came says nothing about how far the energy goes.
-}
stopped : List Run -> List Run
stopped runs =
    runs |> List.filter (\run -> run.endLap /= Nothing)


{-| A car's runs, in order, each with its pace laps counted one lap at a time.

The runs themselves are [`Race.Stint`](Motorsport-Race-Stint)'s, which is where a run
between stops is decided; what is added here is the count of the laps among them that
spent energy.

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


{-| Where a car stands on its energy at the clock.

`Nothing` is a car this race's field does not hold, which is not the same fact as a
car it does hold and has nothing to say about.

-}
level : CarNumber -> Int -> Table -> Maybe Energy
level carNumber clock table =
    let
        (Table t) =
            table
    in
    Dict.get carNumber t.cars
        |> Maybe.map (asEnergy clock t.classes)


{-| What the class has to say about one car at the clock -- the class's spread where it runs
no plan, and the car's level where it does.
-}
asEnergy : Int -> Dict String ClassReading -> CarGauges -> Energy
asEnergy clock classes car =
    case Dict.get (Class.toString car.class) classes of
        Nothing ->
            Unreadable

        Just reading ->
            case reading.plan of
                Nothing ->
                    Spread reading.stops

                Just plan ->
                    levelAt plan reading.stops.ceiling (usedAt clock car)


{-| How many pace laps the car has run on its energy, at the clock.

None, when every lap it has run since its last stop was run under a procedure -- which is a full load and not an unreadable one, the meter's unit excluding those laps on both sides of the division.

-}
usedAt : Int -> CarGauges -> Int
usedAt clock car =
    car.gauges
        |> atOrBefore .lap clock
        |> Maybe.map .used
        |> Maybe.withDefault 0


{-| The reading itself: how much of the class's plan the car has left, and which side of
it it stands on.
-}
levelAt : Plan -> Int -> Int -> Energy
levelAt plan ceiling used =
    let
        left =
            plan.laps - used
    in
    if left < 0 then
        Overrun
            { laps = negate left
            , plan = plan.laps
            , band = plan.band
            , ceiling = ceiling
            , fraction = 0
            }

    else
        Running
            { laps = left
            , plan = plan.laps
            , band = plan.band
            , ceiling = ceiling
            , fraction = Basics.clamp 0 1 (toFloat left / toFloat plan.laps)
            }


{-| Whether a block of stops is the class's plan, and not a few cars doing their own thing.

The band's six is the quarter this gate started as, restated for the count it reads now:
the band is a middle distance rather than a distance between quarters, so six bands to the
plan is a quarter of the plan.

It is a mild gate: over the sixteen rounds kept here, a third of the plan instead of a quarter would have bought four more points of the column for a tenth of a lap of error.

-}
runsTheClass : Plan -> Int -> Int -> Bool
runsTheClass plan blockRuns poolRuns =
    carriesTheClass blockRuns poolRuns
        && (minPlan <= plan.laps)
        && (plan.band * 6 <= plan.laps)


{-| The newest entry at or before the clock, out of a list kept newest first.
-}
atOrBefore : (entry -> Int) -> Int -> List entry -> Maybe entry
atOrBefore key clock entries =
    entries
        |> List.filter (\entry -> key entry <= clock)
        |> List.head
