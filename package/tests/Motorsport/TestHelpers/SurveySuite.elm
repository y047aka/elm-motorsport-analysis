module Motorsport.TestHelpers.SurveySuite exposing (Survey, suite)

{-| What a circuit's `Geometry` module claims about the survey it wrote, checked
against the drawing that survey is projected into.

The geometry modules are generated from OpenStreetMap and never edited by hand,
and no Elm test can compare one to OpenStreetMap; what a test can hold is that
the drawing the degrees arrive at is a faithful reading of them — every place
drawn, none of them moved by the projection's own rounding, and none of them
below its zero.

-}

import Expect
import Motorsport.Circuit.Geodesy exposing (Coordinate, Frame, project)
import Motorsport.Circuit.Shape as Shape exposing (Point)
import Motorsport.Wec.Circuit.Layout exposing (Layout)
import Test exposing (Test, describe, test)


{-| One surveyed place, two ways it is read: the frame's metres before
`Circuit.Layout` rounds them, and the drawing's metres after. A rounded place
stands half a tenth clear of every boundary whatever the survey said, so the
clearance a rounding turns on is worth measuring only on the reading before it.
-}
type alias Place =
    { degrees : Coordinate
    , raw : Point
    , drawn : Point
    }


{-| A circuit's survey and the drawing it is projected into. `box` is where the
circuit stands on the earth, as its own script knows it.
-}
type alias Survey =
    { name : String
    , box : { minLat : Float, maxLat : Float, minLon : Float, maxLon : Float }
    , frame : Frame
    , centreline : List Coordinate
    , pitLane : List Coordinate
    , layout : Layout
    }


{-| The checks every generated survey has to pass.
-}
suite : Survey -> Test
suite survey =
    let
        places =
            placesOf survey
    in
    describe survey.name
        [ test "every surveyed place has a drawn one, and no more have one" <|
            \_ ->
                [ Tuple.pair (List.length survey.centreline) (List.length (Shape.marks survey.layout.shape))
                , Tuple.pair (List.length survey.pitLane) (List.length survey.layout.pitLane)
                ]
                    |> List.filter (\( surveyed, drawn ) -> surveyed /= drawn)
                    |> Expect.equal []
        , test "no surveyed place stands where another rounding could put it" <|
            \_ ->
                places
                    |> List.concatMap (\place -> [ fromAHalfTenth place.raw.x, fromAHalfTenth place.raw.y ])
                    |> List.minimum
                    |> Maybe.withDefault 0
                    |> Expect.atLeast tenthTolerance
        , test "no surveyed place falls below the frame's zero" <|
            \_ ->
                mistakes places (\place -> place.raw.x >= 0 && place.raw.y >= 0)
                    |> Expect.equal []
        , test "the survey stands in the box its circuit is in, and not at swapped degrees" <|
            \_ ->
                mistakes places
                    (\place ->
                        place.degrees.lat
                            >= survey.box.minLat
                            && place.degrees.lat
                            <= survey.box.maxLat
                            && place.degrees.lon
                            >= survey.box.minLon
                            && place.degrees.lon
                            <= survey.box.maxLon
                    )
                    |> Expect.equal []
        ]


placesOf : Survey -> List Place
placesOf survey =
    List.append
        (paired survey.frame survey.centreline (Shape.marks survey.layout.shape))
        (paired survey.frame survey.pitLane survey.layout.pitLane)


paired : Frame -> List Coordinate -> List { r | x : Float, y : Float } -> List Place
paired frame surveyed drawn =
    List.map2
        (\degrees drawing ->
            { degrees = degrees
            , raw = project frame degrees
            , drawn = { x = drawing.x, y = drawing.y }
            }
        )
        surveyed
        drawn


{-| The positions in the survey of the places where a reading of every place
fails.
-}
mistakes : List Place -> (Place -> Bool) -> List Int
mistakes places holds =
    places
        |> List.indexedMap
            (\i place ->
                if holds place then
                    Nothing

                else
                    Just i
            )
        |> List.filterMap identity


{-| How far a value is from the half-tenth a rounding turns on, in metres.
-}
fromAHalfTenth : Float -> Float
fromAHalfTenth value =
    let
        tenths =
            value * 10 - 0.5
    in
    abs (tenths - toFloat (round tenths)) / 10


{-| A projection is a handful of digits wide and two languages round its last
one differently, so a place closer than this to a half-tenth is a place the
drawing cannot decide. The tightest place of either survey here stands 39
micrometres clear; a closer one is worth redrawing the survey from, not
relaxing.
-}
tenthTolerance : Float
tenthTolerance =
    1.0e-6
