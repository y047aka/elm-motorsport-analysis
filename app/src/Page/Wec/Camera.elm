module Page.Wec.Camera exposing (Model, Msg(..), init, held, holds, update)

{-| The camera the raised map is turned with, and the pointer turning it.

A turn is the pointer's travel since the last move, so the camera keeps which pointer is
turning it and where that one was last read: a second finger landing on the drawing is not
the first one's turn.

@docs Model, Msg, init, held, holds, update

-}

import Drag.Handle as Handle exposing (Place, Steps)
import Motorsport.Chart.Tracker3d as Track3d


{-| The way the map is looked at, and the pointer holding it up to the eye now.
-}
type alias Model =
    { eye : Track3d.Model
    , held : Maybe Hold
    }


type alias Hold =
    { pointerId : Int
    , x : Float
    , y : Float
    }


type Msg
    = Grab Place
    | Move Place
    | Release Place
    | Cancel Int
    | Step Steps
    | Wheel { x : Float, y : Float }


init : Model
init =
    { eye = Track3d.init
    , held = Nothing
    }


{-| Whether a pointer is turning the map now.
-}
held : Model -> Bool
held m =
    m.held /= Nothing


{-| Whether that pointer is the one turning the map.
-}
holds : Int -> Model -> Bool
holds pointerId m =
    Maybe.map .pointerId m.held == Just pointerId


update : Msg -> Model -> Model
update msg m =
    case msg of
        Grab place ->
            case m.held of
                Nothing ->
                    { m | held = Just { pointerId = place.id, x = place.x, y = place.y } }

                Just _ ->
                    m

        Move place ->
            case m.held of
                Just h ->
                    if h.pointerId == place.id then
                        { m
                            | eye = Track3d.update (turned (place.x - h.x) (place.y - h.y)) m.eye
                            , held = Just { h | x = place.x, y = place.y }
                        }

                    else
                        m

                Nothing ->
                    m

        Release place ->
            ended place.id m

        Cancel pointerId ->
            ended pointerId m

        Step steps ->
            { m | eye = Track3d.update (Track3d.Roll (toFloat steps.x * keyStep) (negate (toFloat steps.y) * keyStep)) m.eye }

        Wheel travel ->
            { m | eye = Track3d.update (turned (travel.x * wheelRate) (travel.y * wheelRate)) m.eye }


{-| The pointer's travel since the last reading, in the reader's own pixels.
-}
turned : Float -> Float -> Track3d.Msg
turned x y =
    Track3d.Roll (x * Track3d.perPixel) (y * Track3d.perPixel)


ended : Int -> Model -> Model
ended pointerId m =
    case m.held of
        Just h ->
            if h.pointerId == pointerId then
                { m | held = Nothing }

            else
                m

        Nothing ->
            m


keyStep : Float
keyStep =
    degrees 5


{-| A two-finger scroll is taken at a third of the rate a drag is: a mouse wheel's notch is
a hundred pixels at once, where a trackpad's are a few at a time and many a second.
-}
wheelRate : Float
wheelRate =
    1 / 3
