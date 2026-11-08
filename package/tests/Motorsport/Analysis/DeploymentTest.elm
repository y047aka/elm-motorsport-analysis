module Motorsport.Analysis.DeploymentTest exposing (suite)

import Expect
import Motorsport.Analysis.Deployment as Deployment exposing (Deployment(..), Shortfall(..))
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Race.Car exposing (Car)
import Motorsport.Speed as Speed exposing (Speed)
import Motorsport.Wec.Class as Class exposing (Class)
import Motorsport.Wec.Era as Era
import Test exposing (Test, describe, test)


{-| The fixtures are built so the arithmetic comes out whole: every lap of a car
is run at one pace, the trap speeds are whole kilometres an hour, and the classes
hold an odd number of observations, where a median has one value rather than a
pair to choose between.

So a bucket of eleven -- six laps of `rich` at 296 and 304, five of `lean` at 310 --
puts the class's expectation at 304, `rich` at -4 km/h and `lean` at +6, and the
spread between those two means at exactly 5. What a test then asserts is a reading,
not a rounding.
-}
suite : Test
suite =
    describe "Motorsport.Analysis.Deployment"
        [ describe "tableOf and lookup"
            [ test "a lap is compared against the class at its own pace, not against the class" <|
                \_ ->
                    Deployment.tableOf [ rich, lean ]
                        |> Deployment.lookup "1" 6
                        |> Maybe.map residualOf
                        |> Expect.equal (Just (Just (Speed.ofTenths -40)))
            , test "and the other way round reads the other way" <|
                \_ ->
                    Deployment.tableOf [ rich, lean ]
                        |> Deployment.lookup "2" 5
                        |> Maybe.map residualOf
                        |> Expect.equal (Just (Just (Speed.ofTenths 60)))
            , test "the class's own spread is the scale a reading is worth showing on" <|
                \_ ->
                    Deployment.tableOf [ rich, lean ]
                        |> Deployment.spread hypercar 6
                        |> Expect.equal (Just (Speed.ofTenths 50))
            , test "and is read at the clock too, so playback sees the class it had" <|
                \_ ->
                    -- At three laps `lean` has measured three of its five and
                    -- `rich` is 8 short rather than 4: the disagreement between
                    -- them is wider, and a scale taken from the finished race
                    -- would draw the third lap on the sixth lap's numbers.
                    let
                        table =
                            Deployment.tableOf [ rich, lean ]
                    in
                    ( table |> Deployment.spread hypercar 3
                    , table |> Deployment.spread hypercar 6
                    )
                        |> Expect.equal
                            ( Just (Speed.ofTenths 70)
                            , Just (Speed.ofTenths 50)
                            )
            , test "the reading is the laps run so far, cut where the clock is" <|
                \_ ->
                    -- `rich` ran 296 for three laps and 304 for three more: at
                    -- three it is 8 km/h short of its class, and only at six has
                    -- it run the mean that says 4. A column that read the whole
                    -- race would show the second answer on the third lap.
                    let
                        table =
                            Deployment.tableOf [ rich, lean ]
                    in
                    ( table |> Deployment.lookup "1" 3 |> Maybe.map residualOf
                    , table |> Deployment.lookup "1" 6 |> Maybe.map residualOf
                    )
                        |> Expect.equal
                            ( Just (Just (Speed.ofTenths -80))
                            , Just (Just (Speed.ofTenths -40))
                            )
            , test "one lap measured says nothing about a car" <|
                \_ ->
                    -- The bucket has eleven observations, so the class can be
                    -- read; the car cannot, and the two facts are different.
                    Deployment.tableOf [ once, rich, lean ]
                        |> Deployment.lookup "3" 1
                        |> Expect.equal (Just (Unreadable OneReading))
            , test "a car the feed timed but never measured has no reading at all" <|
                \_ ->
                    Deployment.tableOf [ unmeasured, rich, lean ]
                        |> Deployment.lookup "4" 6
                        |> Expect.equal (Just (Unreadable NoReading))
            , test "a lap the field was held down for measured nothing" <|
                \_ ->
                    Deployment.tableOf [ held, rich, lean ]
                        |> Deployment.lookup "5" 6
                        |> Expect.equal (Just (Unreadable NoReading))
            , test "one readable car is no scale for itself" <|
                \_ ->
                    -- Only `lean` can be read here, so its class has no spread
                    -- to be measured on -- which is not the same answer as a
                    -- mean beaten by its own uncertainty.
                    Deployment.tableOf [ lean ]
                        |> Deployment.lookup "2" 5
                        |> Expect.equal (Just (Unreadable NoFieldReading))
            , test "a car alone in its pace bucket has nothing to be against" <|
                \_ ->
                    -- Six laps each, each class of one: the bucket is its own
                    -- median, so every residual is nil and nothing separates the
                    -- two cars. The reading is a difference, and where there is
                    -- no difference the column says so.
                    Deployment.tableOf [ aloneAt "6" 100000, aloneAt "7" 120000 ]
                        |> Deployment.lookup "6" 6
                        |> Expect.equal (Just (Unreadable (Unresolved (Speed.ofTenths 0))))
            , test "a car the round does not hold is not a car with nothing to say" <|
                \_ ->
                    Deployment.tableOf [ rich, lean ]
                        |> Deployment.lookup "99" 6
                        |> Expect.equal Nothing
            ]
        ]


{-| The reading's difference, or `Nothing` where there is no reading to read.
-}
residualOf : Deployment -> Maybe Speed
residualOf deployment =
    case deployment of
        Measured { residual } ->
            Just residual

        Unreadable _ ->
            Nothing



-- FIXTURES


{-| Six laps at one pace: three at 296 km/h at the trap, three at 304 -- eight
short of its class for the first half of its run and level with it for the second.
-}
rich : Car
rich =
    carOf "1"
        [ 296, 296, 296, 304, 304, 304 ]


{-| Five laps at one pace and 310 km/h at the trap the whole way: six over its
class, and no spread of its own.
-}
lean : Car
lean =
    carOf "2" [ 310, 310, 310, 310, 310 ]


once : Car
once =
    carOf "3" [ 300 ]


unmeasured : Car
unmeasured =
    let
        timed =
            carOf "4" [ 300, 300, 300, 300, 300, 300 ]
    in
    { timed | laps = List.map (\lap -> { lap | topSpeed = Nothing }) timed.laps }


{-| Six laps at six different traps, and every one of them under a procedure.
-}
held : Car
held =
    let
        raced =
            carOf "5" [ 296, 300, 304, 308, 312, 316 ]
    in
    { raced | laps = List.map (\lap -> { lap | flag = Lap.SlowZone }) raced.laps }


{-| Six laps of its own, at a pace no other car in the round ran.
-}
aloneAt : String -> Int -> Car
aloneAt number pace =
    { metadata = metadataOf number
    , startPosition = 1
    , laps = List.range 1 6 |> List.map (\lapNumber -> lapAt lapNumber pace 300)
    }


carOf : String -> List Int -> Car
carOf number traps =
    { metadata = metadataOf number
    , startPosition = 1
    , laps = List.indexedMap (\lapNumber kmh -> lapAt (lapNumber + 1) 100000 kmh) traps
    }


metadataOf : String -> Motorsport.Race.Car.Metadata
metadataOf number =
    { carNumber = number
    , drivers = []
    , class = hypercar
    , group = "H"
    , team = "Team " ++ number
    , manufacturer = Manufacturer.unknown
    , imageUrl = Nothing
    }


{-| Every lap at `pace`, measured at `kmh` at the trap.
-}
lapAt : Int -> Int -> Int -> Lap
lapAt lapNumber pace kmh =
    let
        empty =
            Lap.empty
    in
    { empty
        | carNumber = "0"
        , lap = lapNumber
        , time = Just pace
        , topSpeed = Just (Speed.ofKmh (toFloat kmh))
    }


hypercar : Class
hypercar =
    Class.fromString Era.Gt3AsThirdClass "HYPERCAR"
