module Motorsport.Wec.Circuit.RaceShareTest exposing (tests)

{-| Every drawn circuit's reference lap, heights and all, against how its 2026 race shared its laps out between the lines its map gives a distance for.

A race's shares are the medians, over the green-flag laps that neither left nor reached the pit lane, of how far into its lap the car had come at each line: `data/wec/2026/<round>.csv`, every class together.
At Le Mans the lines are the seven of its mini-sectors' the map gives a distance for; everywhere else, the two intermediates and the finish line.

-}

import Expect
import Length
import Motorsport.Circuit.Shape as Shape
import Motorsport.MiniSector as MiniSector
import Motorsport.Simulation.Pace.ReferenceLap as ReferenceLap exposing (ReferenceLap)
import Motorsport.Wec.Circuit.CircuitsTest as Circuits
import Motorsport.Wec.Circuit.Layout exposing (Layout, MiniSectorLines(..))
import Quantity
import Test exposing (Test, describe, test)


{-| How far into the lap, as a share of it, the 2026 race had come at each line, and how far off that the reference lap may share it out.
-}
races : List { name : String, shares : List Float, atMost : Float }
races =
    [ { name = "Barcelona", shares = [ 0.2928, 0.6965, 1 ], atMost = 0.01 }
    , { name = "COTA", shares = [ 0.2126, 0.5926, 1 ], atMost = 0.015 }
    , { name = "Fuji", shares = [ 0.2434, 0.5588, 1 ], atMost = 0.02 }
    , { name = "Le Mans", shares = [ 0.1583, 0.5414, 0.827, 0.9036, 0.9541, 0.9832, 1 ], atMost = 0.02 }
    , { name = "Monza", shares = [ 0.3179, 0.6595, 1 ], atMost = 0.03 }
    , { name = "Spa", shares = [ 0.2793, 0.7462, 1 ], atMost = 0.015 }
    , { name = "São Paulo", shares = [ 0.2576, 0.7663, 1 ], atMost = 0.015 }
    , { name = "Imola", shares = [ 0.2069, 0.5368, 1 ], atMost = 0.015 }
    ]


tests : Test
tests =
    describe "each circuit's reference lap"
        (everyCircuitHeld :: List.map raceTest races)


everyCircuitHeld : Test
everyCircuitHeld =
    test "every circuit the app draws is held to a race" <|
        \_ ->
            List.map .name Circuits.circuits
                |> List.filter (\name -> not (List.any (\race -> race.name == name) races))
                |> Expect.equal []


raceTest : { name : String, shares : List Float, atMost : Float } -> Test
raceTest race =
    test (race.name ++ " shares its lap out as its 2026 race did") <|
        \_ ->
            case List.filter (\circuit -> circuit.name == race.name) Circuits.circuits |> List.head |> Maybe.map .read of
                Just (Ok ( _, layout )) ->
                    let
                        lines =
                            linesOf layout

                        lapLength =
                            Length.inMeters (Shape.length layout.shape)
                    in
                    ( missedBy (ReferenceLap.fromShape { shape = layout.shape, relief = layout.relief }) lapLength lines race.shares
                    , missedBy ReferenceLap.steady lapLength lines race.shares
                    )
                        |> Expect.all
                            [ \_ -> Expect.equal (List.length race.shares) (List.length lines)
                            , Tuple.first >> Expect.atMost race.atMost
                            , \( shaped, steady ) -> Expect.lessThan (steady / 3) shaped
                            ]

                Just (Err problem) ->
                    Expect.fail problem

                Nothing ->
                    Expect.fail (race.name ++ " is not among the circuits the app draws")


{-| Where the lines stand round the lap, in the order a car reaches them.
-}
linesOf : Layout -> List Float
linesOf layout =
    case layout.timingLines.miniSectors of
        MiniSectors published ->
            [ "IP1", "IP2", "PORIN", "POROUT", "SCL1", "FORDOUT", "FL" ]
                |> List.filterMap (\name -> published |> MiniSector.get name |> Maybe.withDefault Nothing)
                |> List.map Length.inMeters

        SectorsOnly ->
            List.map Length.inMeters [ layout.timingLines.sectors.s1, layout.timingLines.sectors.s2, layout.timingLines.sectors.s3 ]


{-| How far, summed over the stretches between the lines, the share of the lap a reference lap spends on each is from the share the race did.
-}
missedBy : ReferenceLap -> Float -> List Float -> List Float -> Float
missedBy lap lapLength lines shares =
    let
        lapTime =
            ReferenceLap.timeTo lap (Length.meters lapLength)

        stretches ends =
            List.map2 (-) ends (0 :: ends)
    in
    List.map2 (\a b -> abs (a - b))
        (stretches (List.map (\metres -> Quantity.ratio (ReferenceLap.timeTo lap (Length.meters metres)) lapTime) lines))
        (stretches shares)
        |> List.sum
