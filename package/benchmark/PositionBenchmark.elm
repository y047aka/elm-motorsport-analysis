module PositionBenchmark exposing (main)

{-| What moving a lap's position out of Elm and into SQL was worth.

The round's laps now carry the place the car was in as it crossed the line,
counted by a window function over `laps` as the round is exported.
`Data.Wec.Laps` reads it off the lap; before, it worked the field out for
itself, once per lap number over every car.

Both halves of that trade are here. Reading a position costs a field on every
line of the JSONL, which is what the first comparison measures, and it saves
`assignPositions`, which is what the second does. `Legacy.WecLaps` is the
module as it stood before, so the two sides are the code that actually ran
rather than a sketch of it.

The fixture is 2025's Le Mans, bounded by lap number: the whole field of
sixty-two cars, since `assignPositions` costs the laps times the cars and a
smaller field would be a different race. `generate-position-fixture.mjs
--laps=N` is where that bound is, and running it at two of them is what says
whether the cost is the shape it looks. It is a fixture of its own because
`PerFrameBenchmark`'s is a whole round -- half distance means nothing in a
bounded one.

-}

import Benchmark exposing (Benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Data.Wec as Wec
import Data.Wec.Laps as Laps
import Dict
import Fixture.Positions as Fixture
import Json.Decode as Decode
import Legacy.WecLaps as Legacy
import Motorsport.Race.Car as Car exposing (Car)
import Motorsport.Wec.Era as Era


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    describe "where the car stood as it crossed the line"
        [ Benchmark.compare "decoding the round's laps"
            "without a position"
            (\_ -> Legacy.fromJsonl Fixture.rawJsonlBeforePosition)
            "with one"
            (\_ -> Laps.fromJsonl Fixture.rawJsonl)
        , Benchmark.compare "putting them on the cars"
            "counting the positions here"
            (\_ -> Legacy.attach legacyLaps grid)
            "reading them off the lap"
            (\_ -> Laps.attach currentLaps grid)
        , Benchmark.benchmark "assignPositions, which the second no longer runs"
            (\_ -> Legacy.assignPositions attached)
        ]


{-| The starting grid both sides attach laps to, decoded once: what is being
measured is the laps, and the summary is the same either way.
-}
grid : List Car
grid =
    case Decode.decodeString (Wec.eventDecoder Era.Gt3AsThirdClass Dict.empty) Fixture.rawSummary of
        Ok event ->
            event.startingGrid.entries |> List.map Car.fromStartingGrid

        Err _ ->
            []


legacyLaps : List Legacy.RawLap
legacyLaps =
    Legacy.fromJsonl Fixture.rawJsonlBeforePosition |> Result.withDefault []


currentLaps : List Laps.RawLap
currentLaps =
    Laps.fromJsonl Fixture.rawJsonl |> Result.withDefault []


{-| Laps on their cars, which is what `assignPositions` was handed. It counts
the field out of the laps' elapsed times and reads no position, so the one
these already carry is overwritten with itself and the work is what it was.
-}
attached : List Car
attached =
    Laps.attach currentLaps grid
