module PositionBenchmark exposing (main)

{-| What reading a lap's position off the file costs, against counting it in Elm.

`Legacy.WecLaps` is `Data.Wec.Laps` without the position, which its
`assignPositions` counts out of the laps instead. Decoding is per line, so it is
asked of one lap; a round is that times the laps. Attaching groups the round's
laps and walks the field per lap number, so it takes the fixture whole.

The fixture is 2025's Le Mans bounded by lap number, with the whole field of
sixty-two cars: `assignPositions` costs the laps times the cars, so a smaller
field would be a different race. The cost is two terms -- finding the round's
last lap walks every lap once, and placing the field walks the cars once per lap
number, overtaking the first somewhere above forty laps -- so it is asked at the
bound and at the eighth, quarter and half of it: two terms need three points to
fix and a fourth to be checked by. `generate-position-fixture.mjs --laps=N`
moves all four.

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
the eighth, quarter and half of it. Built here rather than inside the
benchmark, since attaching is not what is being timed.

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
