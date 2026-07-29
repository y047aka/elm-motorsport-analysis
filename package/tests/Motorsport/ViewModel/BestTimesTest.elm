module Motorsport.ViewModel.BestTimesTest exposing (tests)

import Expect
import Motorsport.Car as Car exposing (Car, Status(..))
import Motorsport.Class as Class
import Motorsport.Clock as Clock
import Motorsport.Driver as Driver
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.RunningOrder as RunningOrder exposing (RunningOrder)
import Motorsport.Sector as Sector
import Motorsport.ViewModel.BestTimes as BestTimes exposing (Scope(..))
import Test exposing (Test, describe, test)
import Time exposing (millisToPosix)


tests : Test
tests =
    describe "Motorsport.ViewModel.BestTimes"
        [ describe "fastestSectors"
            [ test "takes each sector from whichever car was quickest through it" <|
                \_ ->
                    -- No car holds all three: car 1 owns S1, car 2 owns S2 and S3.
                    [ car "1" [ lap 1 6000 ( 1000, 2000, 3000 ) ]
                    , car "2" [ lap 1 6000 ( 1100, 1900, 2900 ) ]
                    ]
                        |> fastestSectors WholeRace
                        |> Expect.equal (Just [ 1000, 1900, 2900 ])
            , test "ignores a sector with no recorded time rather than calling it the quickest" <|
                \_ ->
                    [ car "1" [ lap 1 6000 ( 1000, 2000, 3000 ) ]
                    , car "2" [ lap 1 6000 ( 0, 0, 0 ) ]
                    ]
                        |> fastestSectors WholeRace
                        |> Expect.equal (Just [ 1000, 2000, 3000 ])
            ]
        , describe "Scope"
            [ test "UpToElapsed ignores laps the clock has not reached yet" <|
                \_ ->
                    -- The quicker lap ends at 12.000, after the clock at 6.000.
                    [ car "1"
                        [ lap 1 6000 ( 1000, 2000, 3000 )
                        , lap 2 6000 ( 900, 1900, 2900 )
                        ]
                    ]
                        |> fastestSectorsAt 6000 UpToElapsed
                        |> Expect.equal (Just [ 1000, 2000, 3000 ])
            , test "WholeRace counts every lap, whatever the clock says" <|
                \_ ->
                    [ car "1"
                        [ lap 1 6000 ( 1000, 2000, 3000 )
                        , lap 2 6000 ( 900, 1900, 2900 )
                        ]
                    ]
                        |> fastestSectorsAt 6000 WholeRace
                        |> Expect.equal (Just [ 900, 1900, 2900 ])
            ]
        ]



-- HELPERS


{-| The three fastest sector times in sector order, or `Nothing` if the cars
could not be put into a running order.
-}
fastestSectors : Scope -> List Car -> Maybe (List Duration)
fastestSectors =
    fastestSectorsAt 0


fastestSectorsAt : Duration -> Scope -> List Car -> Maybe (List Duration)
fastestSectorsAt elapsed scope cars =
    runningOrder cars
        |> Maybe.map
            (\order ->
                BestTimes.compute scope { clock = clockAt elapsed, cars = order }
                    |> .fastestSectors
                    |> Sector.values
            )


runningOrder : List Car -> Maybe RunningOrder
runningOrder =
    RunningOrder.fromList { elapsed = 0 }


clockAt : Duration -> Clock.Model
clockAt elapsed =
    Clock.update (millisToPosix 0) (Clock.Set elapsed) Clock.init


{-| A lap of `time`, split into the three given sector times, running from the
end of the previous lap of the same length.
-}
lap : Int -> Duration -> ( Duration, Duration, Duration ) -> Lap
lap lapNumber time ( s1, s2, s3 ) =
    { empty
        | lap = lapNumber
        , time = time
        , elapsed = lapNumber * time
        , sectors =
            { s1 = { time = s1, personalBest = s1 }
            , s2 = { time = s2, personalBest = s2 }
            , s3 = { time = s3, personalBest = s3 }
            }
    }


empty : Lap
empty =
    Lap.empty


car : Car.CarNumber -> List Lap -> Car
car carNumber laps =
    { metadata =
        { carNumber = carNumber
        , class = Class.none
        , group = "Test Group"
        , team = "Test Team"
        , drivers = [ Driver.fromName "Test Driver" ]
        , manufacturer = Manufacturer.Other
        }
    , startPosition = 0
    , laps = laps
    , currentLap = List.head laps
    , lastLap = List.head (List.reverse laps)
    , status = Racing
    , currentDriver = Nothing
    }
