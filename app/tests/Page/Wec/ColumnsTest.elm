module Page.Wec.ColumnsTest exposing (suite)

import Dict
import Drag.Handle exposing (Pointer)
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


suite : Test
suite =
    describe "Page.Wec.Columns"
        [ describe "the opening strip"
            [ test "one column per class, in the order the field puts the classes" <|
                \_ ->
                    Columns.init
                        |> keysOf
                        |> Expect.equal [ classColumnOf "HYPERCAR", classColumnOf "LMGT3" ]
            , test "the tracker trails the class columns" <|
                \_ ->
                    Columns.init
                        |> step (ShowTracker True)
                        |> keys
                        |> Expect.equal (standIns ++ [ Tracker ])
            , test "the class columns are re-read, not frozen" <|
                \_ ->
                    Columns.init
                        |> step (ShowTracker True)
                        |> keysOf
                        |> Expect.equal (standIns ++ [ Tracker ])
            ]
        , describe "settling"
            [ test "picking a column up settles the stand-ins" <|
                \_ ->
                    Columns.init
                        |> step (ShowTracker True)
                        |> step (Grab (Car "1") (pointer 1 0))
                        |> keys
                        |> Expect.equal (standIns ++ [ Tracker ])
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
                    -- The first class's column is carried one column right; the
                    -- tracker stays behind columns that have settled.
                    case standIns of
                        headKey :: nextKey :: _ ->
                            Columns.init
                                |> step (ShowTracker True)
                                |> step (Grab headKey (pointer 1 0))
                                |> step (Carrying (pointer 1 (Columns.widthOf headKey)))
                                |> step (Release (pointer 1 (Columns.widthOf headKey)))
                                |> keys
                                |> Expect.equal
                                    ([ nextKey, headKey ] ++ List.drop 2 standIns ++ [ Tracker ])

                        _ ->
                            Expect.fail "the fixture fields fewer than two classes"
            ]
        , describe "opening and closing"
            [ test "a car opened goes behind the class columns and before the tracker" <|
                \_ ->
                    Columns.init
                        |> step (ShowTracker True)
                        |> step (Open (Car "9"))
                        |> keysOf
                        |> Expect.equal (standIns ++ [ Car "9", Tracker ])
            , test "a class's column opened again joins the back and not its old place" <|
                \_ ->
                    Columns.init
                        |> step (Close (classColumnOf "HYPERCAR"))
                        |> step (Open (classColumnOf "HYPERCAR"))
                        |> keysOf
                        |> Expect.equal [ classColumnOf "LMGT3", classColumnOf "HYPERCAR" ]
            , test "opening a column the strip holds already changes nothing" <|
                \_ ->
                    case standIns of
                        headKey :: _ ->
                            step (Open headKey) Columns.init
                                |> .order
                                |> Expect.equal Columns.init.order

                        [] ->
                            Expect.fail "the fixture fields no class columns"
            , test "the last column standing cannot be closed" <|
                \_ ->
                    Columns.init
                        |> step (Open (Car "9"))
                        |> step (Close (classColumnOf "LMGT3"))
                        |> step (Close (classColumnOf "HYPERCAR"))
                        |> step (Close (Car "9"))
                        |> keysOf
                        |> Expect.equal [ Car "9" ]
            , test "closing a car forgets how far its panel was scrolled" <|
                \_ ->
                    Columns.init
                        |> step (PanelScrolled "1" 42)
                        |> step (Close (Car "1"))
                        |> .scrolls
                        |> Dict.get "1"
                        |> Expect.equal Nothing
            , test "closing a class's column leaves the panels' scrolls alone" <|
                \_ ->
                    Columns.init
                        |> step (PanelScrolled "1" 42)
                        |> step (Close (classColumnOf "HYPERCAR"))
                        |> .scrolls
                        |> Dict.get "1"
                        |> Expect.equal (Just 42)
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
            , test "stepping the tracker fixes it among the columns" <|
                \_ ->
                    -- One step left: the tracker takes the second-to-last
                    -- place of the settled stand-ins.
                    Columns.init
                        |> step (ShowTracker True)
                        |> step (Step Tracker -1)
                        |> keys
                        |> Expect.equal
                            (List.take (List.length standIns - 1) standIns ++ [ Tracker ] ++ List.drop (List.length standIns - 1) standIns)
            ]
        , describe "carries"
            [ test "a step is ignored while a column is carried" <|
                \_ ->
                    let
                        grabbed =
                            Columns.init
                                |> step (Open (Car "9"))
                                |> step (Grab (Car "9") (pointer 1 0))
                    in
                    step (Step (Car "9") -1) grabbed
                        |> .order
                        |> Expect.equal grabbed.order
            , test "a release of a pointer holding nothing does nothing" <|
                \_ ->
                    Columns.update (Just field) (Release (pointer 7 100)) Columns.init
                        |> Expect.equal ( Columns.init, Cmd.none )
            , test "closing the carried column is not undone by letting go" <|
                \_ ->
                    -- The carry settles the stand-ins; closing a column then
                    -- changes the order, and a no-travel release must not put
                    -- back what would reopen it.
                    case standIns of
                        headKey :: _ ->
                            Columns.init
                                |> step (Grab headKey (pointer 1 0))
                                |> step (Close headKey)
                                |> step (Release (pointer 1 0))
                                |> keys
                                |> List.member headKey
                                |> Expect.equal False

                        [] ->
                            Expect.fail "the fixture fields no class columns"
            ]
        , describe "reading the strip"
            [ test "resolve drops cars the field no longer holds and keeps the tracker" <|
                \_ ->
                    Columns.resolve field [ Car "1", Car "9", Tracker ]
                        |> Expect.equal [ Car "1", Tracker ]
            , test "resolve keeps a class the field has cars in and drops one it has none of" <|
                \_ ->
                    Columns.resolve field [ classColumnOf "LMP2", classColumnOf "HYPERCAR" ]
                        |> Expect.equal [ classColumnOf "HYPERCAR" ]
            , test "carsIn answers with the field's own cars, in order, and no class cars" <|
                \_ ->
                    Columns.carsIn field [ Car "9", Car "3", Tracker, Car "1", classColumnOf "HYPERCAR" ]
                        |> List.map (.metadata >> .carNumber)
                        |> Expect.equal [ "3", "1" ]
            , test "a moved column is announced by name and place" <|
                \_ ->
                    Columns.init
                        |> step (Open (Car "9"))
                        |> step (Step (Car "9") -1)
                        |> .announcement
                        |> Expect.equal ("Car #9 moved to column 2 of " ++ String.fromInt (List.length standIns + 1))
            , test "a moved class column is announced by its class" <|
                \_ ->
                    Columns.init
                        |> step (Step (classColumnOf "LMGT3") -1)
                        |> .announcement
                        |> Expect.equal "LMGT3 column moved to column 1 of 2"
            , test "a column is as wide as what it is a column of" <|
                \_ ->
                    Expect.all
                        [\() -> Columns.widthOf (classColumnOf "HYPERCAR") |> Expect.equal Columns.classWidth
                        , \() -> Columns.widthOf (Car "1") |> Expect.equal Columns.width
                        , \() -> Columns.widthOf Tracker |> Expect.equal Columns.width
                        ]
                        ()
            , test "a carry is clamped by the widths that stand, not the pitch that counts" <|
                \_ ->
                    -- The first stand-in stands a narrow slot wide; the second
                    -- column carried past it is held at its right edge, and it
                    -- steps aside by its own slot rather than a full pitch.
                    case standIns of
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
                                    Columns.placements narrow (Columns.carrying carrying) (keysOf carrying)
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
                            Expect.fail "the fixture fields fewer than two stand-ins"
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


{-| The columns the strip opens with: one for each class the fixture's field has
cars out in, in the order its running order puts the classes.
-}
standIns : List StripKey
standIns =
    Columns.keysOf field Columns.init.order


classColumnOf : String -> StripKey
classColumnOf name =
    ClassColumn (classOf name)


pointer : Int -> Float -> Pointer
pointer id x =
    { id = id, x = x }



-- FIXTURE
--
-- Two Hypercars and a GT3 car, every lap of theirs finished by the moment the
-- field is read, so the field has two classes to open a column for. Car 9 is in
-- no race here, which is what a car the field lost reads as. There is no LMP2
-- car, which is what a class with nothing out in it reads as.


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
