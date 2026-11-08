module Motorsport.Analysis.Deployment exposing
    ( Deployment(..), Reading, Shortfall(..), Table
    , tableOf, lookup, spread
    )

{-| What a car does with the speed it is allowed, read off the laps the timing
feed measured.

The feed times a lap twice over: once as a whole, and once at the lap's fastest
point. Those are not one reading and its rounding. The lap time says how much
circuit the car covered per second; the trap speed says how much of the straight it
was still building on as it crossed it. A car that spends its allowance early, or
has nothing left for the end of the straight, loses time in the sector the straight
stands in and arrives at the trap slower; a car that lost the same time in a corner
arrives with the trap untouched. Subtracting what the class did at the same lap
time leaves the difference the straights explain.

That difference is a _deployment_: how much drag a car carries, and how much of its
electrical energy it puts down at the end of a straight rather than keeps. It is a
difference and not a level -- nothing here knows a car's mass or drag area, and no
circuit file is read -- so it says which cars in a class are running richer than
one another, and never how many joules any of them spent.

Two things it cannot tell apart. The first is a tow: the car ahead leaves low pressure in which a
following car reaches the trap quicker for _less_ energy, so a lap run in traffic
reads as richer than the same lap run alone. The second is the line: a car driving
two per cent further round the lap spent two per cent more to drive it, and its
trap speed says nothing about that. Both read as noise at a single lap and wash out
over the many laps a reading is taken from -- except where a whole race is spent
behind the same car.

The reading is taken over the laps run so far: [`lookup`](#lookup) and
[`spread`](#spread) are both given how far the clock has got, so a car on its third
lap is answered from three laps and not from what it runs later.

@docs Deployment, Reading, Shortfall, Table
@docs tableOf, lookup, spread

-}

import Dict exposing (Dict)
import Internal.Statistics as Statistics
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Speed as Speed exposing (Speed)
import Motorsport.Wec.Class as Class exposing (Class)


{-| One car's reading, or the reason there is none.

The second case is not a zero and not a dash the view chose. A car the feed never
measured and a car whose mean stands inside its own uncertainty are two facts, and
a column that drew them alike would claim to know something about both.

-}
type Deployment
    = Measured Reading
    | Unreadable Shortfall


{-| What a car's laps so far say, and how far to trust it.

`residual` is the car's mean against its class at the same pace, signed by which way
it fell; `uncertainty` is the standard error of that mean, held as a magnitude.
Where the uncertainty is the larger of the two, the mean is a coin toss and `lookup`
says so by answering [`Unresolved`](#Shortfall) instead of this.

-}
type alias Reading =
    { residual : Speed
    , uncertainty : Speed
    , laps : Int
    }


{-| Why a car has no reading.

`NoReading` is no lap of the car's so far that counts: it is in the pits, or the
field is held, or the feed left its speed blank. `OneReading` is one, which says
something about that lap and nothing about the car, since a single value has no
spread to be judged against. `Unresolved` carries the uncertainty that swamped the
mean. `NoFieldReading` is the class itself too thin to be a scale for anyone in it.

-}
type Shortfall
    = NoReading
    | OneReading
    | Unresolved Speed
    | NoFieldReading


{-| Every car's readings, and each class's spread, taken once off a race.

A `Table` is built as the round loads and looked a car up in on every frame: a
reading is a mean over a car's laps, and a row that re-derived it from every lap
every frame would read the whole race again to draw one bar.

-}
type Table
    = Table
        { cars : Dict CarNumber CarReadings
        , classes : Dict String (List CarNumber)
        }


type alias CarReadings =
    { class : Class
    , prefixes : List Prefix
    }


{-| One lap of one car as the reading counts it.

`Nothing` where that lap is no observation: a pit lap, a held lap, a lap the feed
gave no trap speed for, or one so far outside its class's own spread at that pace
that it is no reading of a straight at all. The `Nothing`s stay in the list, because
the clock finds a lap by its number: dropping them would move every later lap down
and give a car on lap forty the mean of its first forty _observations_.

-}
type alias LapReading =
    { lap : Int
    , residual : Maybe Speed
    }


{-| What a car has read of itself by one of its own laps.

Kept once per lap rather than once per car, because the column is drawn at a clock:
the bar at lap twenty is the mean of the readings the first twenty laps hold, and a
table that stored one mean per car would answer lap twenty with a number the race
had not run yet -- on a round still running, and again whenever the reader scrubs
the clock back.

So a car carries a reading at every lap it measured, and `atClock` hands out the
newest one at or before the clock. The list is kept newest first, which is where a
clock nearly always is.

`uncertainty` is how far that mean may still move -- the deviation of the readings
behind it over how many there are -- and a reading has to beat it, against the scale
its own class sets at the same clock, to be drawn at all.

-}
type alias Prefix =
    { lap : Int
    , mean : Speed
    , uncertainty : Speed
    , observations : Int
    }


{-| A lap the feed both timed and measured a speed on.

`pace` is the lap's own time, which is the bucket the class is compared within: the
trap speed is read against the class at that pace, and that is the whole of the
comparison.

-}
type alias Observation =
    { class : Class
    , carNumber : CarNumber
    , lap : Int
    , pace : Duration
    , speed : Speed
    }


{-| What a class is called in this table's dictionaries.

`Class` holds a record, and Elm cannot order a record, so a class cannot be a
`Dict` key however apt a key it would make. A class is called by its printed name
elsewhere in a round too -- `Shared`'s pit cycles are keyed the same way -- and one
round holds one class per name.

-}
keyOf : Class -> String
keyOf =
    Class.toString


{-| How wide a pace bucket is, in the milliseconds a `Duration` is kept in: the
class's expectation is held per fifth of a second.

    bucketOf 414321
    --> 2071

Finer than that and a bucket holds a handful of laps and a median of one car;
coarser and a bucket spans cars running two tenths apart, which is more than a
deployment is worth.

-}
bucketOf : Duration -> Int
bucketOf time =
    time // paceBucket


paceBucket : Int
paceBucket =
    200


{-| How many observations a bucket needs before its median is the class's and not
one car's.
-}
minBucket : Int
minBucket =
    4


{-| How many observations a class needs before an outlier fence is cut from it.
Below this the quartiles collapse -- see `Internal.Statistics.upperFenceBy`, which
refuses to fence a set this small -- and the fence would rule out the readings it
was cut to protect.
-}
minFencePool : Int
minFencePool =
    12


{-| Read the race once: the class's expectation at every pace, every car's laps
against it, and which cars each class has.
-}
tableOf : List Car -> Table
tableOf cars =
    let
        observations =
            List.concatMap observationsOf cars

        expectations =
            expectationsOf observations

        observed =
            List.map (observedBy expectations) observations

        fences =
            fencesOf observed

        byCar =
            groupOn (.observation >> .carNumber) observed

        readings =
            cars
                |> List.map
                    (\car ->
                        ( car.metadata.carNumber
                        , { class = car.metadata.class
                          , prefixes =
                                Dict.get car.metadata.carNumber byCar
                                    |> Maybe.withDefault []
                                    |> List.map (lapReadingOf fences)
                                    |> prefixesOf
                          }
                        )
                    )
                |> Dict.fromList

        classNumbers =
            cars
                |> List.map (\car -> ( keyOf car.metadata.class, car.metadata.carNumber ))
                |> groupOn Tuple.first
                |> Dict.map (\_ numbered -> List.map Tuple.second numbered)
    in
    Table
        { cars = readings
        , classes = classNumbers
        }


{-| The laps that count: run at pace, timed, and measured at the trap.

`Lap.atRacePace` is the field's own predicate for a lap that says what the car could
do -- which line it crossed, and which flag was out at it -- rather than a second
one invented here.

-}
observationsOf : Car -> List Observation
observationsOf car =
    List.filterMap
        (\lap ->
            case ( lap.time, lap.topSpeed ) of
                ( Just time, Just speed ) ->
                    if Lap.atRacePace lap then
                        Just
                            { class = car.metadata.class
                            , carNumber = car.metadata.carNumber
                            , lap = lap.lap
                            , pace = time
                            , speed = speed
                            }

                    else
                        Nothing

                ( _, _ ) ->
                    Nothing
        )
        car.laps


{-| An observation and what it says against its class at its own pace.

`Nothing` where the pace bucket it stands in holds too few of the class's laps for
the class to be read from it: the lap was both timed and measured, and still says
nothing on its own.

-}
type alias Observed =
    { observation : Observation
    , residual : Maybe Speed
    }


observedBy : Dict String (Dict Int Speed) -> Observation -> Observed
observedBy expectations observation =
    { observation = observation
    , residual =
        expectationOf expectations observation
            |> Maybe.map (\expected -> Speed.difference observation.speed expected)
    }


lapReadingOf : Dict String Fence -> Observed -> LapReading
lapReadingOf fences observed =
    { lap = observed.observation.lap
    , residual =
        observed.residual
            |> Maybe.andThen (within (Dict.get (keyOf observed.observation.class) fences))
    }


{-| The class's median trap speed in each pace bucket.
-}
expectationsOf : List Observation -> Dict String (Dict Int Speed)
expectationsOf observations =
    observations
        |> groupOn (keyOf << .class)
        |> Dict.map
            (\_ observed ->
                observed
                    |> groupOn (bucketOf << .pace)
                    |> Dict.filter (\_ laps -> List.length laps >= minBucket)
                    |> Dict.map (\_ laps -> medianOf laps)
            )


expectationOf : Dict String (Dict Int Speed) -> Observation -> Maybe Speed
expectationOf expectations observation =
    Dict.get (keyOf observation.class) expectations
        |> Maybe.andThen (Dict.get (bucketOf observation.pace))


{-| Which observations of a class stand far enough out from its own spread of
speeds to be no observation of a straight at all.

A lap joined mid-race, a lap ended in a hurry, a lap measured across a slowdown the
flag did not hold the field for: the bucket's median survives those and the car's
mean would not.

-}
type alias Fence =
    { lower : Int
    , upper : Int
    }


fencesOf : List Observed -> Dict String Fence
fencesOf observed =
    observed
        |> List.filterMap
            (\each ->
                Maybe.map
                    (\residual -> ( keyOf each.observation.class, Speed.toTenths residual ))
                    each.residual
            )
        |> groupOn Tuple.first
        |> Dict.map (\_ byPace -> List.map Tuple.second byPace)
        |> Dict.toList
        |> List.filterMap
            (\( classKey, pooled ) ->
                if List.length pooled >= minFencePool then
                    Statistics.iqrFences (List.sort pooled)
                        |> Maybe.map (\fence -> ( classKey, fence ))

                else
                    Nothing
            )
        |> Dict.fromList


{-| Keep a residual inside its class's fence, and `Nothing` outside it. No fence
keeps everything: with no fence there is nothing to be outside.
-}
within : Maybe Fence -> Speed -> Maybe Speed
within fence residual =
    let
        tenths =
            Speed.toTenths residual
    in
    case fence of
        Nothing ->
            Just residual

        Just { lower, upper } ->
            if tenths >= lower && tenths <= upper then
                Just residual

            else
                Nothing


{-| Every lap the car measured, and what it had read by then. Newest lap first, so
the clock finds its entry at the front.

The mean runs from the car's first measured lap: a stint's worth of extra deployment
reads as a trend, and the mean over the whole run so far is the reading a column can
hold still. A reader who wants the last stint has the lap list for that.

-}
prefixesOf : List LapReading -> List Prefix
prefixesOf readings =
    readings
        |> List.filterMap
            (\reading ->
                Maybe.map (\residual -> ( reading.lap, Speed.toKmh residual )) reading.residual
            )
        |> List.foldl
            (\( lap, value ) ( total, squares, done ) ->
                let
                    observations =
                        List.length done + 1

                    sum =
                        total + value

                    squaresOf =
                        squares + value * value

                    mean =
                        sum / toFloat observations

                    scatter =
                        sqrt (Basics.max 0 (squaresOf / toFloat observations - mean * mean))
                in
                ( sum
                , squaresOf
                , { lap = lap
                  , mean = Speed.ofKmh mean
                  , uncertainty = Speed.ofKmh (scatter / sqrt (toFloat observations))
                  , observations = observations
                  }
                    :: done
                )
            )
            ( 0, 0, [] )
        |> (\( _, _, prefixes ) -> prefixes)


{-| The newest reading at or before the clock.

The car need not have measured that lap -- the reading stands at the last lap it did,
which is what a mean is for.

-}
atClock : Int -> List Prefix -> Maybe Prefix
atClock clock prefixes =
    case prefixes of
        [] ->
            Nothing

        first :: rest ->
            if first.lap <= clock then
                Just first

            else
                atClock clock rest


{-| What the class's cars say about one another at the clock: the spread of their
means.

This is the scale a reading has to beat to be worth a column's width, and it is read
at the same clock as the reading -- a class that has run three laps holds three laps
of disagreement between its cars, not the whole race's.

A car with one observation is in no car's mean and so is no reading of its class
either; a class with one such car has no scale at all, which `lookup` answers with
`NoFieldReading` rather than with a bar.

-}
spread : Class -> Int -> Table -> Maybe Speed
spread class lapsCompleted (Table table) =
    Dict.get (keyOf class) table.classes
        |> Maybe.map
            (List.filterMap
                (\carNumber ->
                    Dict.get carNumber table.cars
                        |> Maybe.andThen (.prefixes >> atClock lapsCompleted)
                        |> Maybe.andThen
                            (\prefix ->
                                if prefix.observations >= 2 then
                                    Just (Speed.toKmh prefix.mean)

                                else
                                    Nothing
                            )
                )
            )
        |> Maybe.andThen
            (\means ->
                if List.length means >= 2 then
                    Just (Speed.ofKmh (deviation means))

                else
                    Nothing
            )


{-| The middle of a set of values.
-}
meanOf : List Float -> Float
meanOf values =
    List.sum values / toFloat (List.length values)


{-| How far a set of values stands from its own middle: the population deviation,
which is what a class's cars are measured by here. A car's own laps are measured the
same way inside `prefixesOf`, where the running sums make it cheap to do every lap
again.
-}
deviation : List Float -> Float
deviation values =
    let
        mean =
            meanOf values
    in
    sqrt (List.sum (List.map (\value -> (value - mean) ^ 2) values) / toFloat (List.length values))


{-| What a car has read of itself by now. The `Int` is how far the clock has got --
the laps this car has completed -- and the readings behind that lap are what the
answer is taken from.

`Nothing` is a car this race's field does not hold, which is not the same fact as a
car it does hold and has nothing to say about.

-}
lookup : CarNumber -> Int -> Table -> Maybe Deployment
lookup carNumber lapsCompleted table =
    let
        (Table t) =
            table
    in
    case Dict.get carNumber t.cars of
        Nothing ->
            Nothing

        Just carReadings ->
            case atClock lapsCompleted carReadings.prefixes of
                Nothing ->
                    Just (Unreadable NoReading)

                Just reading ->
                    Just (readingOf table carReadings.class lapsCompleted reading)


{-| Whether a pile of laps has become a reading: enough of them to have a mean at
all, a class to be measured against, and a difference wider than the mean's own
uncertainty.
-}
readingOf : Table -> Class -> Int -> Prefix -> Deployment
readingOf table class lapsCompleted reading =
    if reading.observations < 2 then
        Unreadable OneReading

    else
        case spread class lapsCompleted table of
            Nothing ->
                Unreadable NoFieldReading

            Just field ->
                if resolvable field reading.uncertainty then
                    Measured { residual = reading.mean, uncertainty = reading.uncertainty, laps = reading.observations }

                else
                    Unreadable (Unresolved reading.uncertainty)


{-| Is a mean worth showing? Further from nothing than its own uncertainty is, by
the standard the class's own cars set: a mean that fails against that is one the
column would be inventing.
-}
resolvable : Speed -> Speed -> Bool
resolvable field uncertainty =
    Speed.toTenths uncertainty < Speed.toTenths field


medianOf : List Observation -> Speed
medianOf observed =
    observed
        |> List.map (Speed.toTenths << .speed)
        |> Statistics.median
        |> Maybe.map Speed.ofTenths
        |> Maybe.withDefault Speed.zero


groupOn : (a -> comparable) -> List a -> Dict comparable (List a)
groupOn keyFor values =
    List.foldr
        (\value groups ->
            let
                key =
                    keyFor value

                held =
                    Dict.get key groups |> Maybe.withDefault []
            in
            Dict.insert key (value :: held) groups
        )
        Dict.empty
        values
