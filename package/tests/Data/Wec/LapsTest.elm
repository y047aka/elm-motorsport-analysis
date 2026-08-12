module Data.Wec.LapsTest exposing (suite)

import Data.Wec.Laps as Laps exposing (RawLap)
import Expect
import Motorsport.Wec.Class as Class
import Motorsport.Driver as Driver
import Motorsport.Instant as Instant
import Motorsport.Wec.Manufacturer exposing (Manufacturer(..))
import Motorsport.Race.Car exposing (Car)
import Motorsport.Sector as Sector
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Data.Wec.Laps"
        [ describe "fromJsonl"
            [ test "decodes empty pitTime as Nothing and a value as Just" <|
                \_ ->
                    case Laps.fromJsonl twoLaps of
                        Ok rawLaps ->
                            let
                                cars =
                                    Laps.attach rawLaps (placeholderCars [ "1" ])

                                pitTimes =
                                    cars |> List.concatMap .laps |> List.map .pitTime
                            in
                            Expect.equal [ Nothing, Just 69953 ] pitTimes

                        Err err ->
                            Expect.fail err
            , test "keeps the laps in the order the lines are in" <|
                \_ ->
                    Laps.fromJsonl twoLaps
                        |> Result.map (List.map .lapNumber)
                        |> Expect.equal (Ok [ 1, 2 ])
            , test "ignores the blank line a trailing newline leaves behind" <|
                \_ ->
                    Laps.fromJsonl twoLaps
                        |> Result.map List.length
                        |> Expect.equal (Ok 2)
            , test "names the line a bad lap is on" <|
                \_ ->
                    (twoLaps ++ """{"carNumber":"1"}\n""")
                        |> Laps.fromJsonl
                        |> Result.mapError (String.left 8)
                        |> Expect.equal (Err "line 3: ")
            ]
        , describe "the mini-sectors of a lap, where the feed splits it that far"
            [ test "reads each one's time and its running total from the line" <|
                \_ ->
                    Laps.fromJsonl lapWithMiniSectors
                        |> Result.map (List.filterMap .miniSectors >> List.map (\ms -> ( ms.scl2, ms.fl )))
                        |> Expect.equal
                            (Ok
                                [ ( { time = Just 20708, elapsedInLap = Just 20708 }
                                  , { time = Just 3483, elapsedInLap = Just 234555 }
                                  )
                                ]
                            )
            , test "reads a mini-sector the CLI left out as one with nothing in it" <|
                \_ ->
                    -- A lap that lost a marker is a key short of fifteen, and
                    -- what is missing is a mini-sector rather than the shape.
                    Laps.fromJsonl lapMissingAMiniSector
                        |> Result.map (List.filterMap .miniSectors >> List.map .fordout)
                        |> Expect.equal (Ok [ { time = Nothing, elapsedInLap = Nothing } ])
            , test "reads a blank time on a mini-sector that still has its total" <|
                \_ ->
                    Laps.fromJsonl lapMissingAMiniSector
                        |> Result.map (List.filterMap .miniSectors >> List.map .fl)
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
                                Laps.attach rawLaps (placeholderCars [ "1" ])
                                    |> List.concatMap .laps
                                    |> List.filterMap .miniSectors
                                    |> List.map (.scl2 >> (\scl2 -> ( scl2.time, scl2.personalBest )))
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
                                Laps.attach rawLaps (placeholderCars [ "1" ])
                                    |> List.concatMap .laps
                                    |> List.filterMap .miniSectors
                                    |> List.map (.scl2 >> .personalBest)
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
                            Laps.attach rawLaps (placeholderCars [ "1" ])
                                |> List.concatMap .laps
                                |> List.map .best
                    in
                    Expect.equal [ Just 100000, Just 95000, Just 95000 ] bests
            , test "assigns 0-based position by elapsed within each lap number" <|
                \_ ->
                    let
                        rawLaps =
                            [ rawLap "1" 1 100000 100000
                            , rawLap "2" 1 95000 95000
                            , rawLap "1" 2 100000 200000
                            , rawLap "2" 2 95000 190000
                            ]

                        positionsByCar =
                            Laps.attach rawLaps (placeholderCars [ "1", "2" ])
                                |> List.map (\car -> ( car.metadata.carNumber, List.map .position car.laps ))
                    in
                    Expect.equal
                        [ ( "1", [ Just 1, Just 1 ] )
                        , ( "2", [ Just 0, Just 0 ] )
                        ]
                        positionsByCar
            , test "leaves cars without matching laps untouched" <|
                \_ ->
                    let
                        rawLaps =
                            [ rawLap "1" 1 100000 100000 ]

                        car2Laps =
                            Laps.attach rawLaps (placeholderCars [ "1", "2" ])
                                |> List.filter (\car -> car.metadata.carNumber == "2")
                                |> List.head
                                |> Maybe.map .laps
                                |> Maybe.withDefault []
                    in
                    Expect.equal [] car2Laps
            , test "preserves pitTime through attach" <|
                \_ ->
                    let
                        rawLaps =
                            [ rawLap "1" 1 100000 100000
                            , { carNumber = "1"
                              , driverName = "D"
                              , lapNumber = 2
                              , lapTime = 100000
                              , sectors = Sector.initialize (always Nothing)
                              , miniSectors = Nothing
                              , elapsed = Instant.fromDuration 200000
                              , pitTime = Just 50000
                              }
                            ]

                        pitTimes =
                            Laps.attach rawLaps (placeholderCars [ "1" ])
                                |> List.concatMap .laps
                                |> List.map .pitTime
                    in
                    Expect.equal [ Nothing, Just 50000 ] pitTimes
            ]
        ]



-- HELPERS


twoLaps : String
twoLaps =
    """{"carNumber":"1","lapNumber":1,"driverName":"D","lap":{"time":"1:35.365","improvement":0},"sectors":{"s1":{"time":"23.155"},"s2":{"time":"29.928"},"s3":{"time":"42.282"}},"elapsed":"1:35.365","pitTime":""}
{"carNumber":"1","lapNumber":2,"driverName":"D","lap":{"time":"3:09.953","improvement":0},"sectors":{"s1":{"time":"23.000"},"s2":{"time":"29.000"},"s3":{"time":"42.000"}},"elapsed":"4:45.318","pitTime":"1:09.953"}
"""


{-| One Le Mans lap, whose feed splits it into fifteen mini-sectors: each one's
own time, and the running total from the line that places it.
-}
lapWithMiniSectors : String
lapWithMiniSectors =
    """{"carNumber":"1","lapNumber":1,"driverName":"D","lap":{"time":"3:54.555","improvement":0},"sectors":{"s1":{"time":"51.908"},"s2":{"time":"1:23.252"},"s3":{"time":"1:39.395"}},"miniSectors":{"scl2":{"time":"20.708","elapsed":"20.708"},"z4":{"time":"13.826","elapsed":"34.534"},"ip1":{"time":"17.374","elapsed":"51.908"},"z12":{"time":"35.154","elapsed":"1:27.062"},"sclc":{"time":"4.685","elapsed":"1:31.747"},"a7_1":{"time":"26.059","elapsed":"1:57.806"},"ip2":{"time":"17.354","elapsed":"2:15.160"},"a8_1":{"time":"6.928","elapsed":"2:22.088"},"sclb":{"time":"37.644","elapsed":"2:59.732"},"porin":{"time":"17.155","elapsed":"3:16.887"},"porout":{"time":"16.786","elapsed":"3:33.673"},"pitref":{"time":"7.954","elapsed":"3:41.627"},"scl1":{"time":"2.885","elapsed":"3:44.512"},"fordout":{"time":"6.560","elapsed":"3:51.072"},"fl":{"time":"3.483","elapsed":"3:54.555"}},"elapsed":"3:54.555","pitTime":""}
"""


{-| The same lap as the file spells one that lost a marker: no `fordout` key at
all, and an `fl` with a running total but no time of its own.
-}
lapMissingAMiniSector : String
lapMissingAMiniSector =
    """{"carNumber":"1","lapNumber":1,"driverName":"D","lap":{"time":"3:37.793","improvement":0},"sectors":{"s1":{"time":"51.908"},"s2":{"time":"1:23.252"},"s3":{"time":"1:22.633"}},"miniSectors":{"scl2":{"time":"20.708","elapsed":"20.708"},"z4":{"time":"13.826","elapsed":"34.534"},"ip1":{"time":"17.374","elapsed":"51.908"},"z12":{"time":"35.154","elapsed":"1:27.062"},"sclc":{"time":"4.685","elapsed":"1:31.747"},"a7_1":{"time":"26.059","elapsed":"1:57.806"},"ip2":{"time":"17.354","elapsed":"2:15.160"},"a8_1":{"time":"6.928","elapsed":"2:22.088"},"sclb":{"time":"37.644","elapsed":"2:59.732"},"porin":{"time":"17.155","elapsed":"3:16.887"},"porout":{"time":"16.786","elapsed":"3:33.673"},"pitref":{"time":"7.954","elapsed":"3:41.627"},"scl1":{"time":"2.885","elapsed":"3:44.512"},"fl":{"time":"","elapsed":"3:37.793"}},"elapsed":"3:37.793","pitTime":""}
"""


{-| A lap the feed did not record, which reaches the app as a `0.000` lap time
and its mini-sectors all the same. Its SCL2 is quicker than any real one here.
-}
lapWithoutALapTime : String
lapWithoutALapTime =
    """{"carNumber":"1","lapNumber":1,"driverName":"D","lap":{"time":"0.000","improvement":0},"sectors":{"s1":{"time":""},"s2":{"time":""},"s3":{"time":""}},"miniSectors":{"scl2":{"time":"19.000","elapsed":"19.000"}},"elapsed":"3:30.000","pitTime":""}
"""


{-| A second lap for the same car, quicker overall and slower through SCL2.
-}
slowerSecondLap : String
slowerSecondLap =
    """{"carNumber":"1","lapNumber":2,"driverName":"D","lap":{"time":"3:30.000","improvement":0},"sectors":{"s1":{"time":"52.000"},"s2":{"time":"1:23.000"},"s3":{"time":"1:15.000"}},"miniSectors":{"scl2":{"time":"21.000","elapsed":"21.000"}},"elapsed":"7:24.555","pitTime":""}
"""


rawLap : String -> Int -> Int -> Int -> RawLap
rawLap carNumber lapNumber lapTime elapsed =
    { carNumber = carNumber
    , driverName = "D"
    , lapNumber = lapNumber
    , lapTime = lapTime
    , sectors = Sector.initialize (always Nothing)
    , miniSectors = Nothing
    , elapsed = Instant.fromDuration elapsed
    , pitTime = Nothing
    }


placeholderCars : List String -> List Car
placeholderCars carNumbers =
    carNumbers |> List.map placeholderCar


placeholderCar : String -> Car
placeholderCar carNumber =
    { metadata =
        { carNumber = carNumber
        , drivers = [ Driver.fromName "D" ]
        , class = Class.none
        , group = ""
        , team = ""
        , manufacturer = Other
        }
    , startPosition = 0
    , laps = []
    }
