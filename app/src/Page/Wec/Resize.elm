module Page.Wec.Resize exposing (Model, Msg(..), Fence, Edge, init, update, grip)

{-| A size the reader sets -- the width of the standings, the row the strip
keeps -- and the grip along the edge that moves it. The page holds one `Model`
per size and forwards every `Msg` through it, the way it forwards the strip's
through `Columns`.

Which axis the pointer is read along is the `Edge`'s, and so the arithmetic
here is the same whichever way the grip lies.

@docs Model, Msg, Fence, Edge, init, update, grip

-}

import Drag
import Drag.Handle as Handle exposing (Pointer)
import Html exposing (Html)


{-| The size the thing stands at, and the carry that moves it: the size follows
the pointer's travel from the size `Drag` was picked up with.
-}
type alias Model =
    { size : Float
    , carried : Drag.State Float
    }


type alias Fence =
    { min : Float
    , max : Float
    , step : Float
    }


{-| Which edge the grip lies along: the axis it reads and steps, the id it
answers to, and the words it is labelled with.
-}
type alias Edge =
    { axis : Handle.Axis
    , id : String
    , label : String
    }


init : Float -> Model
init size =
    { size = size
    , carried = Drag.init
    }


type Msg
    = Grab Pointer
    | Carrying Pointer
    | Release Pointer
    | Cancel Int
    | Step Int


{-| The size follows `Drag`, and a `Cancel` leaves it where the last move left
it -- unlike a carried column, a resize has nothing to put back.
-}
update : Fence -> Msg -> Model -> Model
update fence msg m =
    case msg of
        Grab pointer ->
            { m | carried = Tuple.first (Drag.update (Drag.Pick m.size pointer) m.carried) }

        Carrying pointer ->
            let
                ( carried, _ ) =
                    Drag.update (Drag.Move pointer) m.carried
            in
            case Drag.carrying carried of
                Just carry ->
                    { m | carried = carried, size = clampTo fence (carry.location + Drag.travel carry) }

                Nothing ->
                    { m | carried = carried }

        Release pointer ->
            { m | carried = Tuple.first (Drag.update (Drag.Drop pointer) m.carried) }

        Cancel pointerId ->
            { m | carried = Tuple.first (Drag.update (Drag.Cancel pointerId) m.carried) }

        Step steps ->
            { m | size = clampTo fence (m.size + toFloat steps * fence.step) }


clampTo : Fence -> Float -> Float
clampTo fence =
    clamp fence.min fence.max


{-| The grip along the edge.
-}
grip : Edge -> Model -> Html Msg
grip edge m =
    Handle.resize edge.axis
        { id = edge.id
        , label = edge.label
        , held = Drag.isCarrying m.carried
        , onGrab = Grab
        , onMove = Carrying
        , onDrop = Release
        , onCancel = Cancel
        , onStep = Step
        }
