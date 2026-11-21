module Drag exposing (State, Msg(..), Carry, Done, Outcome(..), init, update, carrying, travel, isCarrying, holds)

{-| The state of one thing being carried by a pointer: picked up, tracked,
let go of, or taken away by the browser. The thing carried is whatever the
caller names -- a column, the size a grip found, the box a floated map keeps
-- and rides along untouched, coming back with the pointer's travel when the
carry ends.

`Drag.Handle` is the event source this is read from: the grip reports a
`Grab`, moves only while it is held, a `Drop` wherever the pointer lets go,
and a `Cancel` after every `Drop` and whenever the browser takes the pointer.
`update` is total over that, so a page can wire a grip's messages straight in
and check nothing first.

A column is moved by `x` alone, a floated box by both, so the carry keeps the
`Place` at both ends and the caller projects what it needs. Which axis a size
moves along is the edge's, and stays there.

@docs State, Msg, Carry, Done, Outcome, init, update, carrying, travel, isCarrying, holds

-}

import Drag.Handle as Handle exposing (Place, Point)


{-| What a grip reports. `Grab` takes the pointer up with something; `Move`
follows it, but only while it is held. `Drop` is the pointer let go of, at
wherever it was then. `Cancel` is a carry ending without that: the browser
taking the pointer, the grip leaving the document, or the release already
having been reported as a `Drop`.
-}
type Msg location
    = Grab location Place
    | Move Place
    | Drop Place
    | Cancel Int


{-| A carry in progress: the two ends of the pointer's path so far, and the
thing being carried as the grab handed it over.
-}
type alias Carry location =
    { location : location
    , pointerId : Int
    , from : Point
    , at : Point
    }


{-| A carry that has ended: the thing carried, and how far the pointer
carried it -- to the `Drop` place's own position for a release, to the last
`Move` for a cancel.
-}
type alias Done location =
    { location : location
    , travel : Point
    }


{-| What one message did to the carry, so that no caller has to ask who is
carrying.

`Began` is a pointer taking a thing up. `Kept` is nothing at all: the message
came from a pointer that is not the one carrying, or nothing is carried, or
the `Cancel` followed the `Drop` that had already ended the carry. `Ended` is
the carry over, with the thing carried and the whole of its travel.

`Stepped` hands the carry the move happened in **as it stood before the
reading**, which is what the caller measures the reading against: the place
minus `carry.at` is the travel since the last reading, and the place minus
`carry.from` the travel since the pointer came down.

-}
type Outcome location
    = Began (Carry location)
    | Kept
    | Stepped (Carry location)
    | Ended (Done location)


{-| Whether something is being carried, and by which pointer.
-}
type State location
    = Idle
    | Dragging (Carry location)


init : State location
init =
    Idle


{-| The one transition. A `Grab` while one is already carried is refused, and
a `Move`, `Drop` or `Cancel` from a pointer that is not the one carrying is
not the carry's business at all.
-}
update : Msg location -> State location -> ( State location, Outcome location )
update msg state =
    case msg of
        Grab location place ->
            let
                at =
                    Handle.point place

                carry =
                    { location = location, pointerId = place.id, from = at, at = at }
            in
            case state of
                Idle ->
                    ( Dragging carry, Began carry )

                Dragging _ ->
                    ( state, Kept )

        Move place ->
            case state of
                Dragging carry ->
                    if carry.pointerId == place.id then
                        ( Dragging { carry | at = Handle.point place }, Stepped carry )

                    else
                        ( state, Kept )

                Idle ->
                    ( state, Kept )

        Drop place ->
            endsWith place place.id state

        Cancel pointerId ->
            case state of
                Dragging carry ->
                    if carry.pointerId == pointerId then
                        ( Idle, ended carry )

                    else
                        ( state, Kept )

                Idle ->
                    ( state, Kept )


endsWith : Place -> Int -> State location -> ( State location, Outcome location )
endsWith place pointerId state =
    case state of
        Dragging carry ->
            if carry.pointerId == pointerId then
                ( Idle, Ended { location = carry.location, travel = travelTo place carry } )

            else
                ( state, Kept )

        Idle ->
            ( state, Kept )


ended : Carry location -> Outcome location
ended carry =
    Ended { location = carry.location, travel = travel carry }


{-| How far the pointer has gone since it came down, to wherever it let go.
-}
travelTo : Place -> Carry location -> Point
travelTo place carry =
    { x = place.x - carry.from.x
    , y = place.y - carry.from.y
    }


{-| The carry in progress, if there is one.
-}
carrying : State location -> Maybe (Carry location)
carrying state =
    case state of
        Dragging carry ->
            Just carry

        Idle ->
            Nothing


{-| How far the pointer has carried since it came down.
-}
travel : Carry location -> Point
travel carry =
    { x = carry.at.x - carry.from.x
    , y = carry.at.y - carry.from.y
    }


{-| Whether that pointer is the one carrying. The message a pointer sends is answered
only when it is, which is what lets two fingers hold two grips at once.
-}
holds : Int -> State location -> Bool
holds pointerId state =
    case state of
        Dragging carry ->
            carry.pointerId == pointerId

        Idle ->
            False


{-| Whether a carry is in progress.
-}
isCarrying : State location -> Bool
isCarrying state =
    case state of
        Dragging _ ->
            True

        Idle ->
            False
