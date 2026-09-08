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

Each is asked in the unit it works in, since a benchmark is run until its
sample is trusted and a round of laps is too much work per run to reach one.
Decoding is per line, so it is asked of one lap: the extra field costs what it
costs there, and a round is that times the laps. Attaching is not -- it groups
the round's laps and walks the field per lap number -- so it takes the fixture
whole.

That fixture is 2025's Le Mans bounded by lap number: the whole field of
sixty-two cars, since `assignPositions` costs the laps times the cars and a
smaller field would be a different race. The bound has to be low enough to
sample, which is low enough to hide how the cost grows -- so `assignPositions`
is asked at the bound and at the halves of it, and what the four say together
is the exponent. Doubling the laps doubles the answer if the cost is the laps
and quadruples it if it is the laps squared, which is the whole question a
round of them cannot be run to settle. `generate-position-fixture.mjs --laps=N`
moves all four.

It is a fixture of its own because `PerFrameBenchmark`'s is a whole round: half
distance means nothing in a bounded one.

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
        [ Benchmark.compare "decoding one lap"
            "without a position"
            (\_ -> Legacy.fromJsonl Fixture.rawLapBeforePosition)
            "with one"
            (\_ -> Laps.fromJsonl Fixture.rawLap)
        , Benchmark.compare "putting a round's laps on the cars"
            "counting the positions here"
            (\_ -> Legacy.attach legacyLaps grid)
            "reading them off the lap"
            (\_ -> Laps.attach currentLaps grid)
        , Benchmark.scale "assignPositions, which the second no longer runs"
            (scaled |> List.map (\( name, cars ) -> ( name, \_ -> Legacy.assignPositions cars )))
        ]


{-| The laps of the round attached to their cars, at the fixture's bound and at
the halves of it. Built here rather than inside the benchmark, since attaching
is not what is being timed.

`assignPositions` counts the field out of the laps' elapsed times and reads no
position, so the one these already carry is overwritten with itself and the
work is what it was.

-}
scaled : List ( String, List Car )
scaled =
    [ Fixture.lapCap // 8, Fixture.lapCap // 4, Fixture.lapCap // 2, Fixture.lapCap ]
        |> List.map (\bound -> ( String.fromInt bound ++ " laps", attachedTo bound ))


attachedTo : Int -> List Car
attachedTo bound =
    Laps.attach (currentLaps |> List.filter (\lap -> lap.lapNumber <= bound)) grid


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
