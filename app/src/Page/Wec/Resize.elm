module Page.Wec.Resize exposing (Model, Msg(..), Fence, Edge, Grows(..), init, update, grip, unmeasured, diagonal, heldBy)

{-| A size the reader sets -- the width of the standings, the box a floated map keeps
-- and the grip along the edge that moves it. The page holds one `Model` per size and
forwards every `Msg` through it, the way it forwards the strip's through `Columns`.

Which edge the grip lies along -- the axis its pointer is read along, the way the
size moves along it, the bounds it holds it between -- is all the `Edge`'s; the
`Model` holds the size and the carry.

@docs Model, Msg, Fence, Edge, Grows, init, update, grip, unmeasured, diagonal, heldBy

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

A size has several grips and one `Model` between them, so the pick rides on the carry,
where it cannot outlive it.

-}
type alias Model =
    { size : Float
    , carried : Drag.State Picked
    }


{-| What the carry holds: the size as the grip took it up, and which grip did.
-}
type alias Picked =
    { size : Float
    , by : String
    }


{-| `Handle.Fence`, under the name the sizes know it by.
-}
type alias Fence =
    Handle.Fence


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
            case Drag.update (Drag.Grab { size = m.size, by = edge.id } place) m.carried of
                ( carried, Drag.Began _ ) ->
                    { m | carried = carried }

                _ ->
                    m

        Move place ->
            let
                ( carried, outcome ) =
                    Drag.update (Drag.Move place) m.carried
            in
            case outcome of
                Drag.Stepped carry ->
                    { m | carried = carried, size = Handle.clampTo edge.fence (carry.location.size + signed edge.grows (along edge place - along edge carry.from)) }

                _ ->
                    { m | carried = carried }

        Drop place ->
            { m | carried = Tuple.first (Drag.update (Drag.Drop place) m.carried) }

        Cancel pointerId ->
            { m | carried = Tuple.first (Drag.update (Drag.Cancel pointerId) m.carried) }

        Step steps ->
            if Drag.isCarrying m.carried then
                -- A step would move the size under the pointer that is carrying it, and the
                -- next move would take the size back to where the pick measured it from.
                m

            else
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
                { m | size = Handle.clampTo edge.fence (m.size + signed edge.grows travel) }


signed : Grows -> Float -> Float
signed grows travel =
    case grows of
        WithPointer ->
            travel

        AgainstPointer ->
            negate travel


{-| Whether the grip named is the one the size is carried by.
-}
heldBy : String -> Model -> Bool
heldBy gripId m =
    case Drag.carrying m.carried of
        Just carry ->
            carry.location.by == gripId

        Nothing ->
            False


{-| How far one arrow key takes a size. Shift is `Handle`'s coarse step.
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
        , size = { now = m.size, fence = edge.fence }
        , onStep = Step
        }
        { id = edge.id
        , label = edge.label
        , held = heldBy edge.id m
        , marks = edge.marks
        , onGrab = Grab
        , onMove = Move
        , onDrop = Drop
        , onCancel = Cancel
        }
