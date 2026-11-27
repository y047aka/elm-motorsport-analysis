module Motorsport.Chart.Tracker.LapScaleTest exposing (tests)

import Expect
import Length
import Motorsport.Chart.Tracker.Config exposing (MiniSectorShares(..), TrackConfig)
import Motorsport.Chart.Tracker.LapScale as LapScale exposing (LapScale)
import Motorsport.Circuit.Shape as Shape
import Motorsport.MiniSector as MiniSector
import Motorsport.Race.Snapshot as Snapshot
import Motorsport.Race.SnapshotTest as SnapshotTest
import Motorsport.Simulation.Pace.Neutralisation as Neutralisation
import Motorsport.Simulation.Pace.ReferenceLap as ReferenceLap
import Motorsport.Simulation.Pace.ReferenceLapTest as ReferenceLapTest
import Motorsport.Wec.Circuit.Layout exposing (MiniSectorLines(..), TimingLines)
import Test exposing (Test, describe, test)


tests : Test
tests =
    describe "Motorsport.Chart.Tracker.LapScale"
        [ describe "distanceAt"
            [ test "runs straight between two lines at the sector grain" <|
                \_ ->
                    [ 0.1, 0.35, 0.75 ]
                        |> List.map (metresAt (LapScale.lapScale ReferenceLap.steady sectorLines bySectors))
                        |> expectAll [ 500, 2500, 7000 ]
            , test "puts a line with no distance where the time between its neighbours does" <|
                \_ ->
                    -- IP1 ends the third of fifteen even stretches, and is the
                    -- first line with a distance: SCL2's end is a third of it.
                    metresAt (LapScale.lapScale ReferenceLap.steady miniSectorLines byMiniSectors) (1 / 15)
                        |> Expect.within (Expect.Absolute 0.001) 600
            , test "pins the scale to every line with a distance" <|
                \_ ->
                    metresAt (LapScale.lapScale ReferenceLap.steady miniSectorLines byMiniSectors) (7 / 15)
                        |> Expect.within (Expect.Absolute 0.001) 6000
            , test "is not pinned to a stretch no lap has set a time for" <|
                \_ ->
                    -- IP2's stretch takes no share, so its line would pin two
                    -- distances to one progress.
                    metresAt (LapScale.lapScale ReferenceLap.steady miniSectorLines withoutIp2) (7 / 15)
                        |> Expect.within (Expect.Absolute 0.001) (1800 + (4 / 12) * (12000 - 1800))
            , test "the last line is reached at the end of the lap" <|
                \_ ->
                    metresAt (LapScale.lapScale ReferenceLap.steady sectorLines bySectors) 1
                        |> Expect.within (Expect.Absolute 0.001) 10000
            , test "the end of the lap is where the drawn lap ends" <|
                \_ ->
                    metresAt stadiumScale 1
                        |> Expect.within (Expect.Absolute 0.001) (Length.inMeters (Shape.length ReferenceLapTest.stadium))
            ]
        , describe "at the pace of a circuit's bends"
            [ test "still puts every line where its distance is" <|
                \_ ->
                    [ 0.2, 0.5 ]
                        |> List.map (metresAt (LapScale.lapScale (ReferenceLap.fromShape { shape = ReferenceLapTest.stadium, relief = Nothing }) stadiumLines stadiumSectors))
                        |> expectAll [ 500, 1150 ]
            , test "runs a straight in less of the time between two lines than a bend" <|
                \_ ->
                    -- Half the time from 500 m to the bend's end at 1,150 m.
                    metresAt (LapScale.lapScale (ReferenceLap.fromShape { shape = ReferenceLapTest.stadium, relief = Nothing }) stadiumLines stadiumSectors) 0.35
                        |> Expect.greaterThan 825
            ]
        , describe "distanceOf"
            [ test "reads a car with no best lap of its own against its class's best" <|
                \_ ->
                    -- At 7.000 car 3 is 1/7 through its opening lap's S2, a stretch of 7.000 that its class's best lap, car 1's 6.000, spends 1.800 on: neutralised through and through, so at an even pace from 500 m to 1,150 m.
                    metresOfCar "3"
                        |> Expect.within (Expect.Absolute 0.01) (500 + 650 / 7)
            , test "reads a car with a best lap against its own" <|
                \_ ->
                    -- At 7.000 car 2 is a third through an S2 of 1.500, which its own 5.000 lap spends 1.500 on: at the reference lap's pace.
                    metresOfCar "2"
                        |> Expect.within (Expect.Absolute 0.01) (metresAt stadiumScale 0.3)
            ]
        , describe "ease"
            [ test "draws a stretch run near its usual time at the reference lap's pace" <|
                \_ ->
                    [ 1000, 1200 ]
                        |> List.map (\took -> easedHalfway { took = took, usually = 1000 })
                        |> expectAll [ halfwayAtPace, halfwayAtPace ]
            , test "draws a stretch run in twice its usual time or more at one speed" <|
                \_ ->
                    [ 2000, 3000 ]
                        |> List.map (\took -> easedHalfway { took = took, usually = 1000 })
                        |> expectAll [ 825, 825 ]
            , test "draws one between in proportion" <|
                \_ ->
                    easedHalfway { took = 1600, usually = 1000 }
                        |> Expect.within (Expect.Absolute 0.01) ((halfwayAtPace + 825) / 2)
            , test "leaves the stretch's ends where they are, however even" <|
                \_ ->
                    [ 1000, 1600, 2000 ]
                        |> List.concatMap
                            (\took ->
                                [ LapScale.ease stadiumScale (Neutralisation.fromTimes { took = took, usually = 1000 }) { share = stadiumSectors.sectors.s2, progress = 0 } |> Length.inMeters
                                , LapScale.ease stadiumScale (Neutralisation.fromTimes { took = took, usually = 1000 }) { share = stadiumSectors.sectors.s2, progress = 1 } |> Length.inMeters
                                ]
                            )
                        |> expectAll [ 500, 1150, 500, 1150, 500, 1150 ]
            ]
        , describe "the grain a round and its circuit disagree on"
            [ -- `lapScale` reads the finer grain only when the round is timed
              -- at it *and* the circuit places the lines; each of these two
              -- combinations answers at the sector grain.
              test "a round timed finer than its circuit places lines" <|
                \_ ->
                    -- Nothing finer than 1,000, 4,000 and 10,000 m is placed,
                    -- and these interpolate those three distances.
                    [ 0.1, 0.35, 0.75 ]
                        |> List.map (metresAt (LapScale.lapScale ReferenceLap.steady sectorsOnlyLines byMiniSectors))
                        |> expectAll [ 500, 2687.5, 7187.5 ]
            , test "lines the circuit places that no round was timed across" <|
                \_ ->
                    -- Fifteen lines placed and a lap split three ways: these
                    -- interpolate 1,800, 6,000 and 12,000 m.
                    [ 0.1, 0.35, 0.75 ]
                        |> List.map (metresAt (LapScale.lapScale ReferenceLap.steady miniSectorLines bySectors))
                        |> expectAll [ 900, 3900, 9000 ]
            ]
        ]


{-| Where the stadium's scale draws a car of the three-car field at 7.000.
-}
metresOfCar : String -> Float
metresOfCar carNumber =
    Snapshot.get carNumber SnapshotTest.fieldWithTailenders
        |> Maybe.map (LapScale.distanceOf stadiumScale SnapshotTest.fieldWithTailenders >> Length.inMeters)
        |> Maybe.withDefault -1


{-| How far round the lap, in metres, a scale puts a progress.
-}
metresAt : LapScale -> Float -> Float
metresAt scale progress =
    Length.inMeters (LapScale.distanceAt scale progress)


expectAll : List Float -> List Float -> Expect.Expectation
expectAll expected actual =
    Expect.all
        ((\_ -> Expect.equal (List.length expected) (List.length actual))
            :: List.map2 (\e a -> \_ -> Expect.within (Expect.Absolute 0.001) e a) expected actual
        )
        ()


stadiumSectors : TrackConfig
stadiumSectors =
    { sectors =
        { s1 = { start = 0, share = 0.2 }
        , s2 = { start = 0.2, share = 0.3 }
        , s3 = { start = 0.5, share = 0.5 }
        }
    , miniSectors = NoMiniSectors
    }


{-| Half way through the stretch from 500 m to 1,150 m, at the reference lap's pace and as a stretch that took what it did would be drawn.
-}
easedHalfway : { took : Int, usually : Int } -> Float
easedHalfway durations =
    LapScale.ease stadiumScale (Neutralisation.fromTimes durations) { share = stadiumSectors.sectors.s2, progress = 0.5 }
        |> Length.inMeters


halfwayAtPace : Float
halfwayAtPace =
    metresAt stadiumScale 0.35


stadiumScale : LapScale
stadiumScale =
    LapScale.lapScale (ReferenceLap.fromShape { shape = ReferenceLapTest.stadium, relief = Nothing }) stadiumLines stadiumSectors


stadiumLines : TimingLines
stadiumLines =
    { sectors = { s1 = Length.meters 500, s2 = Length.meters 1150, s3 = Shape.length ReferenceLapTest.stadium }
    , miniSectors = SectorsOnly
    }


bySectors : TrackConfig
bySectors =
    { sectors =
        { s1 = { start = 0, share = 0.2 }
        , s2 = { start = 0.2, share = 0.3 }
        , s3 = { start = 0.5, share = 0.5 }
        }
    , miniSectors = NoMiniSectors
    }


sectorLines : TimingLines
sectorLines =
    { sectors = { s1 = Length.meters 1000, s2 = Length.meters 4000, s3 = Length.meters 10000 }
    , miniSectors = MiniSectors (everyMiniSector (\_ -> Nothing))
    }


{-| The same three lines on a circuit that divides its lap no finer -- which is
what a round whose feed carries mini-sector shares meets at COTA.
-}
sectorsOnlyLines : TimingLines
sectorsOnlyLines =
    { sectors = { s1 = Length.meters 1000, s2 = Length.meters 4000, s3 = Length.meters 10000 }
    , miniSectors = SectorsOnly
    }


{-| Fifteen stretches taking a fifteenth of the lap each.
-}
byMiniSectors : TrackConfig
byMiniSectors =
    { sectors =
        { s1 = { start = 0, share = 3 / 15 }
        , s2 = { start = 3 / 15, share = 4 / 15 }
        , s3 = { start = 7 / 15, share = 8 / 15 }
        }
    , miniSectors =
        MiniSectorShares
            (everyMiniSector
                (\name ->
                    { start = toFloat (index name) / 15, share = 1 / 15 }
                )
            )
    }


withoutIp2 : TrackConfig
withoutIp2 =
    { byMiniSectors
        | miniSectors =
            MiniSectorShares
                (everyMiniSector
                    (\name ->
                        { start = toFloat (index name) / 15
                        , share =
                            if name == "IP2" then
                                0

                            else
                                1 / 15
                        }
                    )
                )
    }


{-| IP1, IP2 and the finish line.
-}
miniSectorLines : TimingLines
miniSectorLines =
    { sectors = { s1 = Length.meters 1800, s2 = Length.meters 6000, s3 = Length.meters 12000 }
    , miniSectors =
        MiniSectors
            (everyMiniSector
                (\name ->
                    case name of
                        "IP1" ->
                            Just (Length.meters 1800)

                        "IP2" ->
                            Just (Length.meters 6000)

                        "FL" ->
                            Just (Length.meters 12000)

                        _ ->
                            Nothing
                )
            )
    }


{-| The fifteen names of the fixture's circuit, in track order.
-}
names : List String
names =
    [ "SCL2", "Z4", "IP1", "Z12", "SCLC", "A7-1", "IP2", "A8-1", "SCLB", "PORIN", "POROUT", "PITREF", "SCL1", "FORDOUT", "FL" ]


everyMiniSector : (String -> a) -> MiniSector.Named a
everyMiniSector f =
    List.map (\name -> { name = name, value = f name }) names


index : String -> Int
index name =
    names
        |> List.indexedMap
            (\position candidate ->
                if candidate == name then
                    position

                else
                    -1
            )
        |> List.filter (\position -> position /= -1)
        |> List.head
        |> Maybe.withDefault 0
