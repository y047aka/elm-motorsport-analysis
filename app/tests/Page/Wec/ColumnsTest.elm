module Page.Wec.ColumnsTest exposing (suite)

import Dict
import Expect
import Internal.ChangePoints as ChangePoints
import List.Extra
import Motorsport.BestTimes as BestTimes
import Motorsport.Driver as Driver
import Motorsport.Duration exposing (Duration)
import Motorsport.Instant as Instant
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Race as Race
import Motorsport.Race.Car as Car
import Motorsport.Race.Snapshot as Snapshot exposing (Snapshot)
import Motorsport.Wec.Class as Class exposing (Class)
import Motorsport.Wec.Era as Era
import Page.Wec.Columns as Columns exposing (Msg(..), Placement(..), StripKey(..))
import Test exposing (Test, describe, test)
import UI.DragHandle exposing (Pointer)


suite : Test
suite =
    describe "Page.Wec.Columns"
        [ describe "while the stand-ins are live"
            [ test "the tracker trails the class leaders" <|
                \_ ->
                    step (ShowTracker True) Columns.init
                        |> keys
                        |> Expect.equal (leaders ++ [ Tracker ])
            , test "the leaders are re-read, not frozen" <|
                \_ ->
                    step (ShowTracker True) Columns.init
                        |> keysOf
                        |> Expect.equal (leaders ++ [ Tracker ])
            ]
        , describe "settling"
            [ test "picking a column up settles the stand-ins" <|
                \_ ->
                    Columns.init
                        |> step (ShowTracker True)
                        |> step (Grab (Car "1") (pointer 1 0))
                        |> keys
                        |> Expect.equal (leaders ++ [ Tracker ])
            , test "a carry let go of where it began puts back what picking it up settled" <|
                \_ ->
                    -- `before` is the order as the tracker's column stood it,
                    -- not the strip's starting one.
                    let
                        shown =
                            step (ShowTracker True) Columns.init
                    in
                    shown
                        |> step (Grab (Car "1") (pointer 1 0))
                        |> step (Release (pointer 1 0))
                        |> .order
                        |> Expect.equal shown.order
            , test "a carry that lands among the cars fixes the tracker there" <|
                \_ ->
                    -- The first car is carried one column right; the tracker
                    -- stays behind cars that have settled.
                    case leaders of
                        headKey :: nextKey :: _ ->
                            Columns.init
                                |> step (ShowTracker True)
                                |> step (Grab headKey (pointer 1 0))
                                |> step (Carrying (pointer 1 Columns.width))
                                |> step (Release (pointer 1 Columns.width))
                                |> keys
                                |> Expect.equal
                                    ([ nextKey, headKey ] ++ List.drop 2 leaders ++ [ Tracker ])

                        _ ->
                            Expect.fail "the fixture fields fewer than two class leaders"
            ]
        , describe "opening and closing"
            [ test "a car opened goes before the tracker" <|
                \_ ->
                    Columns.init
                        |> step (ShowTracker True)
                        |> step (Open "9")
                        |> keysOf
                        |> List.drop (List.length leaders)
                        |> Expect.equal [ Car "9", Tracker ]
            , test "opening a car the strip already holds changes nothing" <|
                \_ ->
                    case leaders of
                        headKey :: _ ->
                            step (Open (carNumberOf headKey)) Columns.init
                                |> .order
                                |> Expect.equal Columns.init.order

                        [] ->
                            Expect.fail "the fixture fields no class leaders"
            , test "closing the last car leaves an order that is not empty" <|
                \_ ->
                    Columns.init
                        |> step (Open "9")
                        |> step (Close "1")
                        |> step (Close "3")
                        |> step (Close "2")
                        |> step (Close "9")
                        |> keysOf
                        |> Expect.equal [ Car "9" ]
            ]
        , describe "the tracker's column"
            [ test "asking for it twice fields one tracker" <|
                \_ ->
                    Columns.init
                        |> step (ShowTracker True)
                        |> step (ShowTracker True)
                        |> keys
                        |> List.filter ((==) Tracker)
                        |> List.length
                        |> Expect.equal 1
            , test "stepping the tracker fixes it among the cars" <|
                \_ ->
                    -- One step left: the tracker takes the second-to-last
                    -- place of the settled stand-ins.
                    Columns.init
                        |> step (ShowTracker True)
                        |> step (Step Tracker -1)
                        |> keys
                        |> Expect.equal
                            (List.take (List.length leaders - 1) leaders ++ [ Tracker ] ++ List.drop (List.length leaders - 1) leaders)
            ]
        , describe "carries"
            [ test "a step is ignored while a column is carried" <|
                \_ ->
                    let
                        grabbed =
                            Columns.init
                                |> step (Open "9")
                                |> step (Grab (Car "9") (pointer 1 0))
                    in
                    step (Step (Car "9") -1) grabbed
                        |> .order
                        |> Expect.equal grabbed.order
            , test "a release of a pointer holding nothing does nothing" <|
                \_ ->
                    Columns.update (Just field) (Release (pointer 7 100)) Columns.init
                        |> Expect.equal (Columns.init, Cmd.none)
            , test "closing the carried car is not undone by letting go" <|
                \_ ->
                    -- The carry settles the stand-ins; closing a car then
                    -- changes the order, and a no-travel release must not
                    -- put back what would reopen it.
                    case leaders of
                        headKey :: _ ->
                            Columns.init
                                |> step (Grab headKey (pointer 1 0))
                                |> step (Close (carNumberOf headKey))
                                |> step (Release (pointer 1 0))
                                |> keys
                                |> List.member headKey
                                |> Expect.equal False

                        [] ->
                            Expect.fail "the fixture fields no class leaders"
            ]
        , describe "reading the strip"
            [ test "resolve drops cars the field no longer holds and keeps the tracker" <|
                \_ ->
                    Columns.resolve field [ Car "1", Car "9", Tracker ]
                        |> Expect.equal [ Car "1", Tracker ]
            , test "carsIn answers with the field's own cars, in order" <|
                \_ ->
                    Columns.carsIn field [ Car "9", Car "3", Tracker, Car "1" ]
                        |> List.map (.metadata >> .carNumber)
                        |> Expect.equal [ "3", "1" ]
            , test "a moved column is announced by name and place" <|
                \_ ->
                    case leaders of
                        _ :: nextKey :: _ ->
                            Columns.init
                                |> step (Open "9")
                                |> step (Step (Car (carNumberOf nextKey)) -1)
                                |> .announcement
                                |> Expect.equal ("Car #" ++ carNumberOf nextKey ++ " moved to column 1 of " ++ String.fromInt (List.length leaders + 1))

                        _ ->
                            Expect.fail "the fixture fields fewer than two class leaders"
            , test "a carry is clamped by the widths that stand, not the pitch that counts" <|
                \_ ->
                    -- The first stand-in stands a narrow slot wide; the
                    -- second car carried past it is held at its right edge,
                    -- and it steps aside by its own slot rather than a full
                    -- pitch.
                    case leaders of
                        firstKey :: secondKey :: _ ->
                            let
                                narrow key =
                                    if key == firstKey then
                                        130

                                    else
                                        Columns.width

                                carrying =
                                    Columns.init
                                        |> step (Grab secondKey (pointer 1 0))
                                        |> step (Carrying (pointer 1 (-2 * Columns.pitch)))

                                placed =
                                    Columns.placements narrow carrying.carried (keysOf carrying)
                            in
                            Expect.all
                                [ \_ ->
                                    placed
                                        |> List.Extra.getAt 0
                                        |> Expect.equal (Just (Shifted 140))
                                , \_ ->
                                    placed
                                        |> List.Extra.getAt 1
                                        |> Expect.equal (Just (Carried -140))
                                ]
                                ()

                        _ ->
                            Expect.fail "the fixture fields fewer than two class leaders"
            ]
        , describe "the panels' scrolls"
            [ test "a closed panel's scroll is forgotten" <|
                \_ ->
                    Columns.init
                        |> step (PanelScrolled "1" 42)
                        |> step (Close "1")
                        |> .scrolls
                        |> Dict.get "1"
                        |> Expect.equal Nothing
            ]
        ]



-- HELPERS


step : Msg -> Columns.Model -> Columns.Model
step msg model =
    Columns.update (Just field) msg model
        |> Tuple.first


keys : Columns.Model -> List StripKey
keys model =
    model |> keysOf |> Columns.resolve field


keysOf : Columns.Model -> List StripKey
keysOf model =
    Columns.keysOf field model.order


{-| The class leaders the strip starts with, in the order it starts with them.
-}
leaders : List StripKey
leaders =
    Columns.keysOf field Columns.init.order


carNumberOf : StripKey -> String
carNumberOf key =
    case key of
        Car carNumber ->
            carNumber

        Tracker ->
            "tracker"


pointer : Int -> Float -> Pointer
pointer id x =
    { id = id, x = x }



-- FIXTURE
--
-- Two Hypercars and a GT3 car, every lap of theirs finished by the moment
-- the field is read, so each class has a leader to stand in. Car 9 is in no
-- race here, which is what a car the field lost reads as.


field : Snapshot
field =
    Race.fromCars { timeLimit = Instant.raceStart, index = noIndex } [ first, second, gt ]
        |> Snapshot.at { elapsed = Instant.fromDuration 30000 }


first : Car.Car
first =
    carOf "1" "HYPERCAR" [ 5000, 10000, 15000, 20000 ]


second : Car.Car
second =
    carOf "3" "HYPERCAR" [ 6000, 12000, 18000, 24000 ]


gt : Car.Car
gt =
    carOf "2" "LMGT3" [ 7000, 14000 ]


carOf : String -> String -> List Duration -> Car.Car
carOf carNumber class completions =
    { metadata = metadataOf carNumber (classOf class)
    , startPosition = 1
    , laps =
        completions
            |> List.indexedMap (\i elapsed -> lapOf carNumber (i + 1) elapsed)
    }


lapOf : String -> Int -> Duration -> Lap
lapOf carNumber lapNumber elapsed =
    { emptyLap
        | carNumber = carNumber
        , driver = Driver.fromName ("Driver " ++ carNumber)
        , lap = lapNumber
        , position = Just lapNumber
        , time = Just 5000
        , elapsed = Instant.fromDuration elapsed
    }


emptyLap : Lap
emptyLap =
    Lap.empty


{-| The records a round arrives with, which nothing here reads.
-}
noIndex : Race.Index
noIndex =
    { lapCompletions = ChangePoints.empty
    , bestTimeChanges = BestTimes.empty
    , flagChanges = ChangePoints.empty
    }


classOf : String -> Class
classOf =
    Class.fromString Era.Gt3AsThirdClass


metadataOf : String -> Class -> Car.Metadata
metadataOf carNumber class =
    { carNumber = carNumber
    , drivers = [ Driver.fromName ("Driver " ++ carNumber) ]
    , class = class
    , group = "H"
    , team = "Team " ++ carNumber
    , manufacturer = Manufacturer.unknown
    , imageUrl = Nothing
    }
