module Page.Wec.Resize exposing (Model, Msg(..), Fence, Edge, Grows(..), init, update, grip, clampTo, unmeasured, diagonal)

{-| A size the reader sets -- the width of the standings, the box a floated map keeps
-- and the grip along the edge that moves it. The page holds one `Model` per size and
forwards every `Msg` through it, the way it forwards the strip's through `Columns`.

Which edge the grip lies along -- the axis its pointer is read along, the way the
size moves along it, the bounds it holds it between -- is all the `Edge`'s; the
`Model` holds the size and the carry.

@docs Model, Msg, Fence, Edge, Grows, init, update, grip, clampTo, unmeasured, diagonal

-}

import Drag
import Drag.Handle as Handle exposing (Place)
import Html exposing (Html)


{-| Which diagonal the meeting of two edges lies along -- the cursor says it, and the two
edges it is the meeting of say which.
-}
diagonal : Edge -> Edge -> Handle.Direction
diagonal width height =
    case ( width.grows, height.grows ) of
        ( AgainstPointer, AgainstPointer ) ->
            Handle.NorthWest

        ( WithPointer, AgainstPointer ) ->
            Handle.NorthEast

        ( AgainstPointer, WithPointer ) ->
            Handle.SouthWest

        ( WithPointer, WithPointer ) ->
            Handle.SouthEast


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


{-| The bounds a size is held between. A size may have no top of its own: a floated box is
held only by how small it may go, the page being what stops it growing.

A travel is held between two of them too -- how far a box may be shifted along one axis is
said the same way as how wide it may be grown.

-}
type alias Fence =
    { min : Float
    , max : Maybe Float
    }


{-| What nothing has been read yet leaves: wide enough that no window a drag could stop at
is outside it.
-}
unmeasured : Float
unmeasured =
    4000


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
    , cursor : String
    , marks : Bool
    }


init : Float -> Model
init size =
    { size = size
    , carried = Drag.init
    , grip = Nothing
    }


type Msg
    = Grab Place
    | Move Place
    | Drop Place
    | Cancel Int
    | Step Handle.Steps


{-| The place read along the axis this edge is read along. A size is moved by one
coordinate, and the grip at a corner reports both.
-}
along : Edge -> { p | x : Float, y : Float } -> Float
along edge p =
    case edge.axis of
        Handle.Across ->
            p.x

        Handle.Down ->
            p.y


{-| The size follows `Drag`, and a `Cancel` leaves it where the last move left
it -- unlike a carried column, a resize has nothing to put back.
-}
update : Edge -> Msg -> Model -> Model
update edge msg m =
    case msg of
        Grab place ->
            case m.grip of
                Just _ ->
                    m

                Nothing ->
                    { m | carried = Tuple.first (Drag.update (Drag.Grab m.size place) m.carried), grip = Just edge.id }

        Move place ->
            let
                ( carried, outcome ) =
                    Drag.update (Drag.Move place) m.carried
            in
            case outcome of
                Drag.Stepped carry ->
                    { m | carried = carried, size = clampTo edge.fence (carry.location + signed edge.grows (along edge place - along edge carry.from)) }

                _ ->
                    { m | carried = carried }

        Drop place ->
            let
                ( carried, _ ) =
                    Drag.update (Drag.Drop place) m.carried
            in
            { m | carried = carried, grip = holding (Drag.isCarrying carried) m.grip }

        Cancel pointerId ->
            let
                ( carried, _ ) =
                    Drag.update (Drag.Cancel pointerId) m.carried
            in
            { m | carried = carried, grip = holding (Drag.isCarrying carried) m.grip }

        Step steps ->
            let
                travel =
                    toFloat
                        (case edge.axis of
                            Handle.Across ->
                                steps.x

                            Handle.Down ->
                                steps.y
                        )
                        * sizeStep
            in
            { m | size = clampTo edge.fence (m.size + signed edge.grows travel) }


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


{-| The size, kept inside the bounds. A fence with no top is held only from below.
-}
clampTo : Fence -> Float -> Float
clampTo fence size =
    case fence.max of
        Just top ->
            clamp fence.min top size

        Nothing ->
            max fence.min size


{-| How far one arrow key takes a size. Shift is five of them, which `Handle` says.
-}
sizeStep : Float
sizeStep =
    10


{-| The grip along the edge, held when it is the one that took the size up.
-}
grip : Edge -> Model -> Html Msg
grip edge m =
    Handle.resize edge.axis
        { glyph = edge.glyph
        , cursor = edge.cursor
        , size = { now = m.size, min = edge.fence.min, max = edge.fence.max }
        , onStep = Step
        }
        { id = edge.id
        , label = edge.label
        , held = m.grip == Just edge.id
        , marks = edge.marks
        , onGrab = Grab
        , onMove = Move
        , onDrop = Drop
        , onCancel = Cancel
        }
