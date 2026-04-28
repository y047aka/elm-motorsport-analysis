module Data.Wec.LapsTest exposing (suite)

import Data.Wec.Laps as Laps exposing (RawLap)
import Expect
import Json.Decode as Decode
import Motorsport.Car as Car exposing (Car)
import Motorsport.Class as Class
import Motorsport.Driver exposing (Driver)
import Motorsport.Manufacturer exposing (Manufacturer(..))
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Data.Wec.Laps"
        [ describe "decoder"
            [ test "decodes empty pitTime as Nothing and a value as Just" <|
                \_ ->
                    let
                        json =
                            """[
                                {"carNumber":"1","driverName":"D","lapNumber":1,"lapTime":"1:35.365","s1":"23.155","s2":"29.928","s3":"42.282","elapsed":"1:35.365","pitTime":""},
                                {"carNumber":"1","driverName":"D","lapNumber":2,"lapTime":"3:09.953","s1":"23.000","s2":"29.000","s3":"42.000","elapsed":"4:45.318","pitTime":"1:09.953"}
                            ]"""
                    in
                    case Decode.decodeString Laps.decoder json of
                        Ok rawLaps ->
                            let
                                cars =
                                    Laps.attach rawLaps (placeholderCars [ "1" ])

                                pitTimes =
                                    cars |> List.concatMap .laps |> List.map .pitTime
                            in
                            Expect.equal [ Nothing, Just 69953 ] pitTimes

                        Err err ->
                            Expect.fail (Decode.errorToString err)
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
                    Expect.equal [ 100000, 95000, 95000 ] bests
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
                              , s1 = Nothing
                              , s2 = Nothing
                              , s3 = Nothing
                              , elapsed = 200000
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


rawLap : String -> Int -> Int -> Int -> RawLap
rawLap carNumber lapNumber lapTime elapsed =
    { carNumber = carNumber
    , driverName = "D"
    , lapNumber = lapNumber
    , lapTime = lapTime
    , s1 = Nothing
    , s2 = Nothing
    , s3 = Nothing
    , elapsed = elapsed
    , pitTime = Nothing
    }


placeholderCars : List String -> List Car
placeholderCars carNumbers =
    carNumbers |> List.map placeholderCar


placeholderCar : String -> Car
placeholderCar carNumber =
    { metadata =
        { carNumber = carNumber
        , drivers = [ Driver "D" ]
        , class = Class.none
        , group = ""
        , team = ""
        , manufacturer = Other
        }
    , startPosition = 0
    , laps = []
    , currentLap = Nothing
    , lastLap = Nothing
    , status = Car.PreRace
    , currentDriver = Nothing
    }
