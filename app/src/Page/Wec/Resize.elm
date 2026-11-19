module Page.Wec.Resize exposing (Model, Msg(..), Fence, Edge, Grows(..), init, update, grip)

{-| A size the reader sets -- the width of the standings, the box a floated map keeps
-- and the grip along the edge that moves it. The page holds one `Model` per size and
forwards every `Msg` through it, the way it forwards the strip's through `Columns`.

Which edge the grip lies along -- the axis its pointer is read along, the way the
size moves along it, the bounds it holds it between -- is all the `Edge`'s; the
`Model` holds the size and the carry.

@docs Model, Msg, Fence, Edge, Grows, init, update, grip

-}

import Drag
import Drag.Handle as Handle exposing (Pointer)
import Html exposing (Html)


{-| Which way the size moves when the pointer travels along the axis. `WithPointer`
is a grip on the far edge of what it bounds: the standings' grip lies on their
right edge, and a travel right widens them. `AgainstPointer` is a grip on the near
edge: the grip along a floated map's top edge lies above it, and a travel down
shortens it.

This belongs to the edge rather than to the size: an edge already says which side
it bounds, and pairing a `Down` grip with the wrong one of these is a row that
draggs backwards in silence.

-}
type Grows
    = WithPointer
    | AgainstPointer


{-| The size the thing stands at and the carry that moves it: the size follows the
pointer's travel from the size `Drag` was picked up with.
-}
type alias Model =
    { size : Float
    , carried : Drag.State Float
    }


type alias Fence =
    { min : Float
    , max : Float
    }


{-| Which edge the grip lies along: the axis its pointer is read along, the way the size
moves along it, the bounds it holds the size between, the id it answers to, the
words it is labelled with, and the mark it shows -- `""` where the cursor is mark
enough.
-}
type alias Edge =
    { axis : Handle.Axis
    , grows : Grows
    , fence : Fence
    , id : String
    , label : String
    , glyph : String
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


{-| The size follows `Drag`, and a `Cancel` leaves it where the last move left
it -- unlike a carried column, a resize has nothing to put back.
-}
update : Edge -> Msg -> Model -> Model
update edge msg m =
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
                    { m | carried = carried, size = clampTo edge.fence (carry.location + signed edge.grows (Drag.travel carry)) }

                Nothing ->
                    { m | carried = carried }

        Release pointer ->
            { m | carried = Tuple.first (Drag.update (Drag.Drop pointer) m.carried) }

        Cancel pointerId ->
            { m | carried = Tuple.first (Drag.update (Drag.Cancel pointerId) m.carried) }


signed : Grows -> Float -> Float
signed grows travel =
    case grows of
        WithPointer ->
            travel

        AgainstPointer ->
            negate travel


clampTo : Fence -> Float -> Float
clampTo fence =
    clamp fence.min fence.max


{-| The grip along the edge.
-}
grip : Edge -> Model -> Html Msg
grip edge m =
    Handle.resize edge.axis
        edge.glyph
        { id = edge.id
        , label = edge.label
        , held = Drag.isCarrying m.carried
        , onGrab = Grab
        , onMove = Carrying
        , onDrop = Release
        , onCancel = Cancel
        }
