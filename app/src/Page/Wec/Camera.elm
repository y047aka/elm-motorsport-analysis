module Page.Wec.Camera exposing (Model, Msg(..), init, update)

{-| The camera the raised map is turned with, and the pointer turning it.

A turn is the pointer's travel since the last move, and `Drag` keeps the carry that says
it: which pointer is turning the map, what it is, and where that one was last read. The
device rides along as the thing carried, since it is what says which way the travel counts.

@docs Model, Msg, init, update

-}

import Drag
import Drag.Handle as Handle exposing (Place)
import Motorsport.Chart.Tracker3d as Track3d


{-| The way the map is looked at, and the pointer holding it up to the eye now.
-}
type alias Model =
    { eye : Track3d.Model
    , carried : Drag.State Handle.Device
    }


type Msg
    = Grab Handle.Device Place
    | Move Place
    | Drop Place
    | Cancel Int
    | Wheel { x : Float, y : Float }


init : Model
init =
    { eye = Track3d.init
    , carried = Drag.init
    }


update : Msg -> Model -> Model
update msg m =
    case msg of
        Grab what place ->
            { m | carried = Tuple.first (Drag.update (Drag.Grab what place) m.carried) }

        Move place ->
            case Drag.update (Drag.Move place) m.carried of
                ( carried, Drag.Stepped turn ) ->
                    { m
                        | carried = carried
                        , eye =
                            Track3d.update
                                (turned (runs turn.location * (place.x - turn.at.x)) (runs turn.location * (place.y - turn.at.y)))
                                m.eye
                    }

                ( carried, _ ) ->
                    { m | carried = carried }

        Drop place ->
            { m | carried = Tuple.first (Drag.update (Drag.Drop place) m.carried) }

        Cancel pointerId ->
            { m | carried = Tuple.first (Drag.update (Drag.Cancel pointerId) m.carried) }

        Wheel travel ->
            { m | eye = Track3d.update (turned (travel.x * wheelRate) (travel.y * wheelRate)) m.eye }


{-| Which way the pointer's travel counts, by what the pointer is: the mouse is the device
the hand moves, and the map turns the other way for it than for a finger on the surface.
-}
runs : Handle.Device -> Float
runs what =
    case what of
        Handle.Mouse ->
            -1

        Handle.Touch ->
            1


{-| The pointer's travel since the last reading, in the reader's own pixels.
-}
turned : Float -> Float -> Track3d.Msg
turned x y =
    Track3d.Roll (negate (x * Track3d.perPixel)) (negate (y * Track3d.perPixel))


{-| A two-finger scroll is taken at a third of the rate a drag is: a mouse wheel's notch is
a hundred pixels at once, where a trackpad's are a few at a time and many a second.
-}
wheelRate : Float
wheelRate =
    1 / 3
