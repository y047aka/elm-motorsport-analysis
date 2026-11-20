module Page.Wec.Resize exposing (Model, Msg(..), Fence, Edge, Grows(..), init, update, grip, cappedTo)

{-| A size the reader sets -- the width of the standings, the box a floated map keeps
-- and the grip along the edge that moves it. The page holds one `Model` per size and
forwards every `Msg` through it, the way it forwards the strip's through `Columns`.

Which edge the grip lies along -- the axis its pointer is read along, the way the
size moves along it, the bounds it holds it between -- is all the `Edge`'s; the
`Model` holds the size and the carry.

@docs Model, Msg, Fence, Edge, Grows, init, update, grip, cappedTo

-}

import Drag
import Drag.Handle as Handle exposing (Pointer)
import Html exposing (Html)


{-| Which way the size moves when the pointer travels along the axis: `WithPointer`
says a travel right or down makes it bigger, `AgainstPointer` says a travel left or
up does. Which of them an edge is follows from which side it bounds -- the
standings' grip lies on their right edge, and a travel right widens them; the grip
along a floated map's top edge lies above it, and a travel down shortens it.

This belongs to the edge rather than to the size: an edge already says which side
it bounds, and pairing a `Down` grip with the wrong one of these is a row that
draggs backwards in silence.

-}
type Grows
    = WithPointer
    | AgainstPointer


{-| The size the thing stands at and the carry that moves it: the size follows the
pointer's travel from the size `Drag` was picked up with.

A size has grips -- along each of its two edges, and at the corners where those meet --
and one `Model` between them, so which of them holds it is kept beside the carry: `grip`
is the id of the one that does, and `Nothing` is none.

-}
type alias Model =
    { size : Float
    , carried : Drag.State Float
    , grip : Maybe String
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
    , grip = Nothing
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
            case m.grip of
                Just _ ->
                    m

                Nothing ->
                    { m | carried = Tuple.first (Drag.update (Drag.Pick m.size pointer) m.carried), grip = Just edge.id }

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
            let
                ( carried, _ ) =
                    Drag.update (Drag.Drop pointer) m.carried
            in
            { m | carried = carried, grip = holding (Drag.isCarrying carried) m.grip }

        Cancel pointerId ->
            let
                ( carried, _ ) =
                    Drag.update (Drag.Cancel pointerId) m.carried
            in
            { m | carried = carried, grip = holding (Drag.isCarrying carried) m.grip }


{-| The grip holding the size, until nothing is carried any more. A second pointer's
release leaves the first holding on, and `Drag` says so.
-}
holding : Bool -> Maybe String -> Maybe String
holding stillCarried held =
    if stillCarried then
        held

    else
        Nothing


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


{-| The edge with its `Fence`'s top taken down to a ceiling the caller knows. A size
is bounded by its `Fence` and sometimes by something of the page's besides: a floated
box cannot grow past the window its corner stands in.
-}
cappedTo : Float -> Edge -> Edge
cappedTo ceiling edge =
    { edge | fence = { min = edge.fence.min, max = min edge.fence.max ceiling } }


{-| The grip along the edge, held when it is the one that took the size up.
-}
grip : Edge -> Model -> Html Msg
grip edge m =
    Handle.resize edge.axis
        edge.glyph
        { id = edge.id
        , label = edge.label
        , held = m.grip == Just edge.id
        , onGrab = Grab
        , onMove = Carrying
        , onDrop = Release
        , onCancel = Cancel
        }
