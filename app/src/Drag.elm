module Drag exposing (State, Msg(..), Carry, Done, init, update, carrying, travel, isCarrying)

{-| The state of one thing being carried by a pointer: picked up, tracked,
let go of, or taken away by the browser. The thing carried is whatever the
caller names -- a column, the width a grip found -- and rides along untouched,
coming back with the pointer's travel when the carry ends.

`UI.DragHandle` is the event source this is read from: the grip reports a
`Pick`, moves only while it is held, a `Drop` wherever the pointer lets go,
and a `Cancel` after every `Drop` and whenever the browser takes the pointer.
`update` is total over that, so a page can wire a grip's messages straight in
and check nothing first.

@docs State, Msg, Carry, Done, init, update, carrying, travel, isCarrying

-}

import UI.DragHandle exposing (Pointer)


{-| What a grip reports. `Pick` takes the pointer up with something; `Move`
follows it, but only while it is held. `Drop` is the pointer let go of, at
wherever it was then. `Cancel` is a carry ending without that: the browser
taking the pointer, the grip leaving the document, or the release already
having been reported as a `Drop`.
-}
type Msg location
    = Pick location Pointer
    | Move Pointer
    | Drop Pointer
    | Cancel Int


{-| A carry in progress: where the pointer came down, where it stands, and
the thing being carried as the pick handed it over.
-}
type alias Carry location =
    { location : location
    , pointerId : Int
    , from : Float
    , at : Float
    }


{-| A carry that has ended: the thing carried, and how far the pointer
carried it -- to the `Drop` pointer's own position for a release, to the last
`Move` for a cancel.
-}
type alias Done location =
    { location : location
    , travel : Float
    }


{-| Whether something is being carried, and by which pointer.
-}
type State location
    = Idle
    | Dragging (Carry location)


{-| Nothing is being carried.
-}
init : State location
init =
    Idle


{-| The one transition. A `Pick` while one is already carried is refused, and
a `Move`, `Drop` or `Cancel` from a pointer that is not the one carrying is
not the carry's business at all. A `Drop` or `Cancel` that ends a carry
reports a `Done`; `Cancel` arrives after every `Drop` as well, which is why
the answer to it here is often nothing.
-}
update : Msg location -> State location -> ( State location, Maybe (Done location) )
update msg state =
    case msg of
        Pick location pointer ->
            case state of
                Idle ->
                    ( Dragging { location = location, pointerId = pointer.id, from = pointer.x, at = pointer.x }
                    , Nothing
                    )

                Dragging _ ->
                    ( state, Nothing )

        Move pointer ->
            ( case state of
                Dragging carry ->
                    if carry.pointerId == pointer.id then
                        Dragging { carry | at = pointer.x }

                    else
                        state

                Idle ->
                    state
            , Nothing
            )

        Drop pointer ->
            endsWith pointer.x pointer.id state

        Cancel pointerId ->
            case state of
                Dragging carry ->
                    if carry.pointerId == pointerId then
                        ( Idle, Just { location = carry.location, travel = carry.at - carry.from } )

                    else
                        ( state, Nothing )

                Idle ->
                    ( state, Nothing )


endsWith : Float -> Int -> State location -> ( State location, Maybe (Done location) )
endsWith x pointerId state =
    case state of
        Dragging carry ->
            if carry.pointerId == pointerId then
                ( Idle, Just { location = carry.location, travel = x - carry.from } )

            else
                ( state, Nothing )

        Idle ->
            ( state, Nothing )


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
travel : Carry location -> Float
travel carry =
    carry.at - carry.from


{-| Whether a carry is in progress, whatever it is carrying.
-}
isCarrying : State location -> Bool
isCarrying state =
    case state of
        Dragging _ ->
            True

        Idle ->
            False
