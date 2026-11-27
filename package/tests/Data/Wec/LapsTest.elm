module Data.Wec.LapsTest exposing (suite)

import Data.Wec.Laps as Laps exposing (RawLap)
import Dict exposing (Dict)
import Expect
import Motorsport.Class as Class
import Motorsport.Instant as Instant
import Motorsport.Lap as Lap
import Motorsport.Manufacturer exposing (unknown)
import Motorsport.MiniSector as MiniSector
import Motorsport.Race.Car exposing (Car)
import Motorsport.Sector as Sector
import Motorsport.TestHelpers.Driver exposing (driverNamed)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Data.Wec.Laps"
        [ describe "fromJsonl"
            [ test "reads the two ends of a stop off the two laps that carry them" <|
                \_ ->
                    case Laps.fromJsonl aStop of
                        Ok rawLaps ->
                            let
                                crossings =
                                    Laps.attach miniSectorNames rawLaps (placeholderCars [ "1" ])
                                        |> List.concatMap .laps
                                        |> List.map .crossing
                            in
                            Expect.equal [ Lap.NoCrossing, Lap.EntryAtEnd, Lap.ExitAtStart 69953 ] crossings

                        Err err ->
                            Expect.fail err
            , test "a lap that came out and went straight back in carries both" <|
                \_ ->
                    case Laps.fromJsonl aDoubleStop of
                        Ok rawLaps ->
                            let
                                crossings =
                                    Laps.attach miniSectorNames rawLaps (placeholderCars [ "1" ])
                                        |> List.concatMap .laps
                                        |> List.map .crossing
                            in
                            Expect.equal [ Lap.EntryAtEnd, Lap.ExitAndEntry 46857, Lap.ExitAtStart 69107 ] crossings

                        Err err ->
                            Expect.fail err
            , test "keeps the laps in the order the lines are in" <|
                \_ ->
                    Laps.fromJsonl twoLaps
                        |> Result.map (List.map .lapNumber)
                        |> Expect.equal (Ok [ 1, 2 ])
            , test "reads which flag was out at the line, each of the five" <|
                -- The reading of a pace turns on this table, and two arms
                -- swapped would relabel which real laps count while every other
                -- test here went on passing.
                \_ ->
                    decodeFlags [ "GF", "FCY", "SF", "FF", "RF" ]
                        |> Expect.equal
                            [ Ok [ Lap.Green ]
                            , Ok [ Lap.FullCourseYellow ]
                            , Ok [ Lap.SlowZone ]
                            , Ok [ Lap.Finish ]
                            , Ok [ Lap.Red ]
                            ]
            , test "a flag the feed has never sent fails the file rather than reading as green" <|
                \_ ->
                    String.replace "\"flagAtFl\":\"GF\"" "\"flagAtFl\":\"XX\"" twoLaps
                        |> Laps.fromJsonl
                        |> Expect.err
            , test "ignores the blank line a trailing newline leaves behind" <|
                \_ ->
                    Laps.fromJsonl twoLaps
                        |> Result.map List.length
                        |> Expect.equal (Ok 2)
            , test "fails a lap that arrives with no place in the field" <|
                \_ ->
                    """{"carNumber":"1","lapNumber":1,"driverName":"D","lap":{"time":"1:35.365","improvement":0},"sectors":{"s1":{"time":"23.155"},"s2":{"time":"29.928"},"s3":{"time":"42.282"}},"elapsed":"1:35.365","crossingFinishLineInPit":"","pitTime":"","flagAtFl":"GF"}
"""
                        |> Laps.fromJsonl
                        |> Result.mapError (String.left 8)
                        |> Expect.equal (Err "line 1: ")
            , test "names the line a bad lap is on" <|
                \_ ->
                    (twoLaps ++ """{"carNumber":"1"}
""")
                        |> Laps.fromJsonl
                        |> Result.mapError (String.left 8)
                        |> Expect.equal (Err "line 3: ")
            ]
        , describe "the mini-sectors of a lap, where the feed splits it that far"
            [ test "reads each one's time and its running total from the line" <|
                \_ ->
                    Laps.fromJsonl lapWithMiniSectors
                        |> Result.map (List.filterMap .miniSectors >> List.map (\ms -> ( read "SCL2" ms, read "FL" ms )))
                        |> Expect.equal
                            (Ok
                                [ ( { time = Just 20708, elapsedInLap = Just 20708 }
                                  , { time = Just 3483, elapsedInLap = Just 234555 }
                                  )
                                ]
                            )
            , test "puts each time under the name the file gives it, in the order the shares name them" <|
                \_ ->
                    -- `fromJsonl` reads the file's keys without an order, and
                    -- `attach` lays them in the order the round's shares name
                    -- them. A time left on its neighbour's name is the mistake
                    -- this catches; no two times on this lap are the same, which
                    -- makes such a swap show.
                    Laps.fromJsonl lapWithMiniSectors
                        |> Result.map
                            (\rawLaps ->
                                Laps.attach miniSectorNames rawLaps (placeholderCars [ "1" ])
                                    |> List.concatMap .laps
                                    |> List.filterMap .miniSectors
                                    |> List.concatMap MiniSector.toList
                                    |> List.map (Tuple.mapSecond .time)
                            )
                        |> Expect.equal
                            (Ok
                                [ ( "SCL2", Just 20708 )
                                , ( "Z4", Just 13826 )
                                , ( "IP1", Just 17374 )
                                , ( "Z12", Just 35154 )
                                , ( "SCLC", Just 4685 )
                                , ( "A7-1", Just 26059 )
                                , ( "IP2", Just 17354 )
                                , ( "A8-1", Just 6928 )
                                , ( "SCLB", Just 37644 )
                                , ( "PORIN", Just 17155 )
                                , ( "POROUT", Just 16786 )
                                , ( "PITREF", Just 7954 )
                                , ( "SCL1", Just 2885 )
                                , ( "FORDOUT", Just 6560 )
                                , ( "FL", Just 3483 )
                                ]
                            )
            , test "reads a mini-sector the CLI left out as one with nothing in it" <|
                \_ ->
                    -- A name short of the round's fifteen is a mini-sector the
                    -- feed had nothing to say about, not a file of the wrong
                    -- shape.
                    Laps.fromJsonl lapMissingAMiniSector
                        |> Result.map (List.filterMap .miniSectors >> List.map (read "FORDOUT"))
                        |> Expect.equal (Ok [ { time = Nothing, elapsedInLap = Nothing } ])
            , test "reads a blank time on a mini-sector that still has its total" <|
                \_ ->
                    Laps.fromJsonl lapMissingAMiniSector
                        |> Result.map (List.filterMap .miniSectors >> List.map (read "FL"))
                        |> Expect.equal (Ok [ { time = Nothing, elapsedInLap = Just 217793 } ])
            , test "leaves a round whose feed records none without any" <|
                \_ ->
                    Laps.fromJsonl twoLaps
                        |> Result.map (List.map .miniSectors)
                        |> Expect.equal (Ok [ Nothing, Nothing ])
            , test "carries the car's running best for each of them through attach" <|
                \_ ->
                    -- The second lap's SCL2 is the slower of the two, so the
                    -- baseline it is rated against stays the first lap's.
                    Laps.fromJsonl (lapWithMiniSectors ++ slowerSecondLap)
                        |> Result.map
                            (\rawLaps ->
                                Laps.attach miniSectorNames rawLaps (placeholderCars [ "1" ])
                                    |> List.concatMap .laps
                                    |> List.filterMap .miniSectors
                                    |> List.map (\ms -> ( ms |> MiniSector.get "SCL2" |> Maybe.andThen .time, ms |> MiniSector.get "SCL2" |> Maybe.andThen .personalBest ))
                            )
                        |> Expect.equal
                            (Ok [ ( Just 20708, Just 20708 ), ( Just 21000, Just 20708 ) ])
            , test "keeps the mini-sectors of a lap with no lap time out of that best" <|
                \_ ->
                    -- The quicker SCL2 belongs to the lap the feed has no time
                    -- for, which the records throw out; the baseline is the
                    -- slower one the car set on a lap it did run.
                    Laps.fromJsonl (lapWithoutALapTime ++ slowerSecondLap)
                        |> Result.map
                            (\rawLaps ->
                                Laps.attach miniSectorNames rawLaps (placeholderCars [ "1" ])
                                    |> List.concatMap .laps
                                    |> List.filterMap .miniSectors
                                    |> List.map (\ms -> ms |> MiniSector.get "SCL2" |> Maybe.andThen .personalBest)
                            )
                        |> Expect.equal (Ok [ Nothing, Just 21000 ])
            ]
        , describe "attach"
            [ test "accumulates per-car best lap times" <|
                \_ ->
                    let
                        rawLaps =
                            [ rawLap "1" 1 100000 100000
                            , rawLap "1" 2 95000 195000
                            , rawLap "1" 3 105000 300000
                            ]

                        bests =
                            Laps.attach miniSectorNames rawLaps (placeholderCars [ "1" ])
                                |> List.concatMap .laps
                                |> List.map .best
                    in
                    Expect.equal [ Just 100000, Just 95000, Just 95000 ] bests
            , test "carries the place in the field each lap arrives with, and turns the feed's unranked zero into no place" <|
                \_ ->
                    let
                        rawLaps =
                            [ rawLapAt 1 "1" 1 100000 100000
                            , rawLapAt 0 "2" 1 95000 95000
                            , rawLapAt 1 "1" 2 100000 200000
                            , rawLapAt 0 "2" 2 95000 190000
                            ]

                        positionsByCar =
                            Laps.attach miniSectorNames rawLaps (placeholderCars [ "1", "2" ])
                                |> List.map (\car -> ( car.metadata.carNumber, List.map .position car.laps ))
                    in
                    Expect.equal
                        [ ( "1", [ Just 1, Just 1 ] )
                        , ( "2", [ Nothing, Nothing ] )
                        ]
                        positionsByCar
            , test "leaves cars without matching laps untouched" <|
                \_ ->
                    let
                        rawLaps =
                            [ rawLap "1" 1 100000 100000 ]

                        car2Laps =
                            Laps.attach miniSectorNames rawLaps (placeholderCars [ "1", "2" ])
                                |> List.filter (\car -> car.metadata.carNumber == "2")
                                |> List.head
                                |> Maybe.map .laps
                                |> Maybe.withDefault []
                    in
                    Expect.equal [] car2Laps
            ]
        ]



-- HELPERS


{-| The track order the round's shares name the mini-sectors in, which is the
order `attach` holds a lap's in.
-}
miniSectorNames : List String
miniSectorNames =
    [ "SCL2", "Z4", "IP1", "Z12", "SCLC", "A7-1", "IP2", "A8-1", "SCLB", "PORIN", "POROUT", "PITREF", "SCL1", "FORDOUT", "FL" ]


{-| What the file says about one mini-sector, and nothing about one it left out.
-}
read : String -> Dict String Laps.RawMiniSector -> Laps.RawMiniSector
read name byName =
    Dict.get name byName |> Maybe.withDefault { time = Nothing, elapsedInLap = Nothing }


twoLaps : String
twoLaps =
    """{"carNumber":"1","lapNumber":1,"position":0,"driverName":"D","lap":{"time":"1:35.365","improvement":0},"sectors":{"s1":{"time":"23.155"},"s2":{"time":"29.928"},"s3":{"time":"42.282"}},"elapsed":"1:35.365","crossingFinishLineInPit":"","pitTime":"","flagAtFl":"GF"}
{"carNumber":"1","lapNumber":2,"position":0,"driverName":"D","lap":{"time":"3:09.953","improvement":0},"sectors":{"s1":{"time":"23.000"},"s2":{"time":"29.000"},"s3":{"time":"42.000"}},"elapsed":"4:45.318","crossingFinishLineInPit":"","pitTime":"1:09.953","flagAtFl":"GF"}
"""


{-| A lap on the road, the lap the car came in on, and the lap it came back out
on -- the shape every stop in a round has.
-}
aStop : String
aStop =
    """{"carNumber":"1","lapNumber":1,"position":0,"driverName":"D","lap":{"time":"1:35.365","improvement":0},"sectors":{"s1":{"time":"23.155"},"s2":{"time":"29.928"},"s3":{"time":"42.282"}},"elapsed":"1:35.365","crossingFinishLineInPit":"","pitTime":"","flagAtFl":"GF"}
{"carNumber":"1","lapNumber":2,"position":0,"driverName":"D","lap":{"time":"1:41.000","improvement":0},"sectors":{"s1":{"time":"23.000"},"s2":{"time":"29.000"},"s3":{"time":"49.000"}},"elapsed":"3:16.365","crossingFinishLineInPit":"B","pitTime":"","flagAtFl":"GF"}
{"carNumber":"1","lapNumber":3,"position":0,"driverName":"D","lap":{"time":"3:09.953","improvement":0},"sectors":{"s1":{"time":"1:38.953"},"s2":{"time":"29.000"},"s3":{"time":"42.000"}},"elapsed":"6:26.318","crossingFinishLineInPit":"","pitTime":"1:09.953","flagAtFl":"GF"}
"""


{-| A car that came back out and went straight in again, which the feed states
as one lap carrying both ends of a stop.
-}
aDoubleStop : String
aDoubleStop =
    """{"carNumber":"1","lapNumber":1,"position":0,"driverName":"D","lap":{"time":"1:41.000","improvement":0},"sectors":{"s1":{"time":"23.000"},"s2":{"time":"29.000"},"s3":{"time":"49.000"}},"elapsed":"1:41.000","crossingFinishLineInPit":"B","pitTime":"","flagAtFl":"GF"}
{"carNumber":"1","lapNumber":2,"position":0,"driverName":"D","lap":{"time":"2:46.857","improvement":0},"sectors":{"s1":{"time":"1:15.857"},"s2":{"time":"29.000"},"s3":{"time":"1:02.000"}},"elapsed":"4:27.857","crossingFinishLineInPit":"B","pitTime":"46.857","flagAtFl":"GF"}
{"carNumber":"1","lapNumber":3,"position":0,"driverName":"D","lap":{"time":"3:09.107","improvement":0},"sectors":{"s1":{"time":"1:38.107"},"s2":{"time":"29.000"},"s3":{"time":"42.000"}},"elapsed":"7:36.964","crossingFinishLineInPit":"","pitTime":"1:09.107","flagAtFl":"GF"}
"""


{-| One Le Mans lap, whose feed splits it into fifteen mini-sectors: each one's
own time, and the running total from the line that places it.
-}
lapWithMiniSectors : String
lapWithMiniSectors =
    """{"carNumber":"1","lapNumber":1,"position":0,"driverName":"D","lap":{"time":"3:54.555","improvement":0},"sectors":{"s1":{"time":"51.908"},"s2":{"time":"1:23.252"},"s3":{"time":"1:39.395"}},"miniSectors":{"SCL2":{"time":"20.708","elapsed":"20.708"},"Z4":{"time":"13.826","elapsed":"34.534"},"IP1":{"time":"17.374","elapsed":"51.908"},"Z12":{"time":"35.154","elapsed":"1:27.062"},"SCLC":{"time":"4.685","elapsed":"1:31.747"},"A7-1":{"time":"26.059","elapsed":"1:57.806"},"IP2":{"time":"17.354","elapsed":"2:15.160"},"A8-1":{"time":"6.928","elapsed":"2:22.088"},"SCLB":{"time":"37.644","elapsed":"2:59.732"},"PORIN":{"time":"17.155","elapsed":"3:16.887"},"POROUT":{"time":"16.786","elapsed":"3:33.673"},"PITREF":{"time":"7.954","elapsed":"3:41.627"},"SCL1":{"time":"2.885","elapsed":"3:44.512"},"FORDOUT":{"time":"6.560","elapsed":"3:51.072"},"FL":{"time":"3.483","elapsed":"3:54.555"}},"elapsed":"3:54.555","crossingFinishLineInPit":"","pitTime":"","flagAtFl":"GF"}
"""


{-| The one lap line, asked under each flag the feed spells.
-}
decodeFlags : List String -> List (Result String (List Lap.Flag))
decodeFlags codes =
    codes
        |> List.map
            (\code ->
                String.replace "\"flagAtFl\":\"GF\"" ("\"flagAtFl\":\"" ++ code ++ "\"") lapWithMiniSectors
                    |> Laps.fromJsonl
                    |> Result.map (List.map .flagAtFl)
            )


{-| The same lap as the file spells one it is a mini-sector short of: no
`fordout` key at all, and an `fl` with a running total but no time of its own.
-}
lapMissingAMiniSector : String
lapMissingAMiniSector =
    """{"carNumber":"1","lapNumber":1,"position":0,"driverName":"D","lap":{"time":"3:37.793","improvement":0},"sectors":{"s1":{"time":"51.908"},"s2":{"time":"1:23.252"},"s3":{"time":"1:22.633"}},"miniSectors":{"SCL2":{"time":"20.708","elapsed":"20.708"},"Z4":{"time":"13.826","elapsed":"34.534"},"IP1":{"time":"17.374","elapsed":"51.908"},"Z12":{"time":"35.154","elapsed":"1:27.062"},"SCLC":{"time":"4.685","elapsed":"1:31.747"},"A7-1":{"time":"26.059","elapsed":"1:57.806"},"IP2":{"time":"17.354","elapsed":"2:15.160"},"A8-1":{"time":"6.928","elapsed":"2:22.088"},"SCLB":{"time":"37.644","elapsed":"2:59.732"},"PORIN":{"time":"17.155","elapsed":"3:16.887"},"POROUT":{"time":"16.786","elapsed":"3:33.673"},"PITREF":{"time":"7.954","elapsed":"3:41.627"},"SCL1":{"time":"2.885","elapsed":"3:44.512"},"FL":{"time":"","elapsed":"3:37.793"}},"elapsed":"3:37.793","crossingFinishLineInPit":"","pitTime":"","flagAtFl":"GF"}
"""


{-| A lap the feed did not record, which reaches the app as a `0.000` lap time
and its mini-sectors all the same. Its SCL2 is quicker than any real one here.
-}
lapWithoutALapTime : String
lapWithoutALapTime =
    """{"carNumber":"1","lapNumber":1,"position":0,"driverName":"D","lap":{"time":"0.000","improvement":0},"sectors":{"s1":{"time":""},"s2":{"time":""},"s3":{"time":""}},"miniSectors":{"SCL2":{"time":"19.000","elapsed":"19.000"}},"elapsed":"3:30.000","crossingFinishLineInPit":"","pitTime":"","flagAtFl":"GF"}
"""


{-| A second lap for the same car, quicker overall and slower through SCL2.
-}
slowerSecondLap : String
slowerSecondLap =
    """{"carNumber":"1","lapNumber":2,"position":0,"driverName":"D","lap":{"time":"3:30.000","improvement":0},"sectors":{"s1":{"time":"52.000"},"s2":{"time":"1:23.000"},"s3":{"time":"1:15.000"}},"miniSectors":{"SCL2":{"time":"21.000","elapsed":"21.000"}},"elapsed":"7:24.555","crossingFinishLineInPit":"","pitTime":"","flagAtFl":"GF"}
"""


rawLap : String -> Int -> Int -> Int -> RawLap
rawLap carNumber lapNumber lapTime elapsed =
    { carNumber = carNumber
    , driver = driverNamed "D"
    , lapNumber = lapNumber
    , position = 0
    , lapTime = lapTime
    , sectors = Sector.initialize (always Nothing)
    , miniSectors = Nothing
    , elapsed = Instant.fromDuration elapsed
    , crossingFinishLineInPit = False
    , pitTime = Nothing
    , flagAtFl = Lap.Green
    }


{-| The same lap, at a named place in the field.
-}
rawLapAt : Int -> String -> Int -> Int -> Int -> RawLap
rawLapAt position carNumber lapNumber lapTime elapsed =
    let
        lap =
            rawLap carNumber lapNumber lapTime elapsed
    in
    { lap | position = position }


placeholderCars : List String -> List Car
placeholderCars carNumbers =
    carNumbers |> List.map placeholderCar


placeholderCar : String -> Car
placeholderCar carNumber =
    { metadata =
        { carNumber = carNumber
        , drivers = [ driverNamed "D" ]
        , class = Class.none
        , group = ""
        , team = ""
        , manufacturer = unknown
        , imageUrl = Nothing
        }
    , startPosition = 0
    , laps = []
    }
