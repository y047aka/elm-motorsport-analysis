module Motorsport.RaceControlTest exposing (suite)

import Expect
import Motorsport.Car as Car exposing (Car)
import Motorsport.Class as Class
import Motorsport.Clock as Clock
import Motorsport.Driver as Driver
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer exposing (Manufacturer(..))
import Motorsport.RaceControl as RaceControl
import Motorsport.RunningOrder as RunningOrder
import Motorsport.TimelineEvent as TimelineEvent
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "RaceControl"
        [ describe "status is a function of the elapsed time, not of the path taken to it"
            [ test "landing inside a pit window puts the car in the pits" <|
                \_ ->
                    initialModel
                        |> skipTo 180000
                        |> statusOf "1"
                        |> Expect.equal (Just Car.InPit)
            , test "landing between the pit exit and the next event leaves the car racing" <|
                \_ ->
                    initialModel
                        |> skipTo 250000
                        |> statusOf "1"
                        |> Expect.equal (Just Car.Racing)
            , test "jumping clear past a retirement retires the car" <|
                \_ ->
                    initialModel
                        |> skipTo 1000000
                        |> statusOf "1"
                        |> Expect.equal (Just Car.Retired)
            , test "rewinding back into a pit window puts the car back in the pits" <|
                \_ ->
                    initialModel
                        |> skipTo 200000
                        |> skipBy -20000
                        |> statusOf "1"
                        |> Expect.equal (Just Car.InPit)
            , test "rewinding from a retirement brings the car back to racing" <|
                \_ ->
                    initialModel
                        |> skipTo 1000000
                        |> skipTo 250000
                        |> statusOf "1"
                        |> Expect.equal (Just Car.Racing)
            , test "one jump and many small steps to the same elapsed agree" <|
                \_ ->
                    let
                        inOneJump =
                            initialModel |> skipTo 260000

                        inManySteps =
                            List.foldl (\_ m -> skipBy 1000 m) initialModel (List.range 1 260)
                    in
                    Expect.equal
                        (statusOf "1" inOneJump)
                        (statusOf "1" inManySteps)
            , test "a car still running past the time limit takes the chequered flag, not a retirement" <|
                \_ ->
                    initialModel
                        |> skipTo 7300000
                        |> statusOf "2"
                        |> Expect.equal (Just Car.Checkered)
            ]
        , describe "SetCount"
            [ test "moving the lap counter forward carries the status with it" <|
                \_ ->
                    -- The end of lap 1 is the instant before car "1" completes
                    -- lap 2, which it spends in the pits.
                    initialModel
                        |> RaceControl.update (RaceControl.SetCount 1)
                        |> statusOf "1"
                        |> Expect.equal (Just Car.InPit)
            ]
        ]



-- FIXTURE
-- Car "1" retires after three laps, pitting on lap 2. Car "2" runs past the two
-- hour mark, so the rounded time limit is 2h -- which is what makes car "1"'s
-- final lap a retirement rather than a chequered flag.


initialModel : RaceControl.Model
initialModel =
    let
        cars =
            [ retiringCar, survivingCar ]
    in
    RaceControl.fromCars (TimelineEvent.fromCars cars) cars
        |> Maybe.withDefault RaceControl.placeholder


retiringCar : Car
retiringCar =
    carWith "1"
        [ lapAt "1" 1 100000
        , lapAt "1" 2 200000 |> withPitTime (Just 30000)
        , lapAt "1" 3 300000
        ]


survivingCar : Car
survivingCar =
    carWith "2"
        [ lapAt "2" 1 100000
        , lapAt "2" 2 7300000
        ]



-- HELPERS


skipTo : Int -> RaceControl.Model -> RaceControl.Model
skipTo elapsed m =
    skipBy (elapsed - Clock.getElapsed m.clock) m


skipBy : Int -> RaceControl.Model -> RaceControl.Model
skipBy duration =
    RaceControl.update (RaceControl.SkipTime duration)


statusOf : Car.CarNumber -> RaceControl.Model -> Maybe Car.Status
statusOf carNumber m =
    m.cars
        |> RunningOrder.toList
        |> List.filter (\car -> car.metadata.carNumber == carNumber)
        |> List.head
        |> Maybe.map .status


carWith : Car.CarNumber -> List Lap -> Car
carWith carNumber laps =
    { metadata =
        { carNumber = carNumber
        , drivers = [ Driver.fromName "Test Driver" ]
        , class = Class.none
        , group = "H"
        , team = "Test Team"
        , manufacturer = Other
        }
    , startPosition = 1
    , laps = laps
    , currentLap = Nothing
    , lastLap = Nothing
    , status = Car.PreRace
    , currentDriver = Nothing
    }


lapAt : Car.CarNumber -> Int -> Int -> Lap
lapAt carNumber lapNumber elapsed =
    let
        base =
            Lap.empty
    in
    { base
        | carNumber = carNumber
        , driver = Driver.fromName "Test Driver"
        , lap = lapNumber
        , position = Just 1
        , elapsed = elapsed
    }


withPitTime : Maybe Int -> Lap -> Lap
withPitTime pitTime lap =
    { lap | pitTime = pitTime }
