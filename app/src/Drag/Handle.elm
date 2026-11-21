module Drag.Handle exposing (Axis(..), Button(..), Device(..), Direction(..), Place, Point, Steps, Size, Config, resize, corner, view, events, eventsByButton, arrowKeys)

{-| A grip that carries something: one along a line, one at a corner, and a surface that
is dragged anywhere on -- by the pointer, or a step at a time by the arrow keys for the
grips that answer to them.

Every grip reads the pointer in both directions at once. Which of the two a size moves
along is the caller's, and `Axis` is where it says so.

The grip holds no state of its own -- `held` is the caller's, and the carry
behind it is `Drag`'s business. What the grip adds is the pointer's path: the
`drag-handle` custom element calls `setPointerCapture`, which Elm cannot, so every move and the release come back to the grip even once the pointer has left
it. A move is listened for only while `held` says one is, and the release is listened for
always: the pointer can be let go of before the frame that would have added a move.

A drawing the reader drags anywhere on is no grip -- it wants none of what a grip is made
of -- but it reads the pointer the same way, and so takes
[`eventsByButton`](#eventsByButton) and [`arrowKeys`](#arrowKeys). Such a surface is where the
two buttons split: the left carries the thing, the right turns what it shows.

@docs Axis, Button, Device, Direction, Place, Point, Steps, Size, Config, resize, corner, view, events, eventsByButton, arrowKeys

-}

import Html exposing (Html, text)
import Html.Attributes exposing (attribute, class, id, title)
import Html.Events exposing (on, preventDefaultOn)
import Json.Decode as Decode exposing (Decoder)


{-| The axis a grip reads the pointer along: `Across` is `clientX`, `Down` is `clientY`.
The grip that answers to keys steps along them too -- `Across` is ← →, `Down` is ↑ ↓.
-}
type Axis
    = Across
    | Down


{-| Which button took the pointer up. `Secondary` -- the right one, which on a trackpad is
the two-finger drag -- is what a drawing hands to the operation the reader is not doing,
and the page says what each of the two starts. The middle button starts nothing.
-}
type Button
    = Primary
    | Secondary


{-| What the pointer is. `Touch` is the surface itself being touched -- a finger, a pen --
and the world is moved under it; `Mouse` is a device the hand moves, and a drawing answers
it the other way.
-}
type Device
    = Mouse
    | Touch


{-| Which corner of a box a grip stands at. It says which way the box grows, and so
which way the cursor turns: the two corners of one diagonal share a cursor.

A corner grows both sizes at once, which is no one size for the grip to name, so it stays
out of the arrow keys and says no `aria-valuenow`.

-}
type Direction
    = NorthWest
    | NorthEast
    | SouthWest
    | SouthEast


{-| Which pointer, and where it is. Two fingers can hold two grips at once, and each
reports its own release.
-}
type alias Place =
    { id : Int
    , x : Float
    , y : Float
    }


{-| How far apart two places are -- a travel, with no pointer to say whose it is.
-}
type alias Point =
    { x : Float
    , y : Float
    }


{-| How many steps the arrow keys took a thing along each axis. The keys come one at
a time, so a caller never sees both moved. Shift is the coarse step, five of them at a
press.
-}
type alias Steps =
    { x : Int
    , y : Int
    }


{-| The size a splitter bounds, and the bounds it is held between. A reader hears these
when the grip takes the focus; otherwise a size is nothing but what the thing looks.
-}
type alias Size =
    { now : Float
    , min : Float
    , max : Maybe Float
    }


{-| What every grip is wired with, whichever of them it is.

A grip's own state is the caller's: `held` says whether this grip is the
one being carried, and moves are only reported while it is. The release is
reported always, and says where it happened: a carry let go of before the
next frame has reported no moves at all.

`onCancel` is the carry ending without being let go of: the browser taking
the pointer for itself, or the grip leaving the document. It also follows
every `onDrop`, and both arrive whether or not anything is held.

`marks` says whether the grip marks itself: a `title` the pointer reads out, and a light
while it is held.

-}
type alias Config msg =
    { id : String
    , label : String
    , held : Bool
    , marks : Bool
    , onGrab : Place -> msg
    , onMove : Place -> msg
    , onDrop : Place -> msg
    , onCancel : Int -> msg
    }


{-| The grip for carrying a thing along, stepped by the arrow keys once it has the
focus.
-}
view : (Int -> msg) -> Config msg -> Html msg
view step config =
    grip
        (Carry "ArrowLeft ArrowRight")
        { id = config.id
        , label = config.label
        , held = config.held
        , marks = config.marks
        , size = Nothing
        , hint = "← →"
        , classes = "grid place-content-center w-5 h-5 rounded-md text-[11px] select-none transition-colors hover:bg-accent hover:text-accent-foreground"
        , cursor =
            if config.held then
                "cursor-grabbing"

            else
                "cursor-grab"
        , glyph = "⠿"
        , events = events config ++ [ stepWith leftRight step ]
        }


{-| The same grip lying along an edge to resize what it bounds: the pointer's
travel is the size's, and the arrow keys step it once the grip has the focus. `Across`
lies along a column edge, `Down` along a row edge.

The `size` is what the splitter says about itself -- the ARIA's `aria-valuenow` and its
two ends -- since a size only the pointer can reach is a size no reader hears.

The `glyph` is the mark drawn along the edge. An empty one leaves the cursor the
only thing saying where the grip is -- and asks the wrapper to centre along the
mark's own axis only: `justify-content: center` sizes a track to its content, and a
`w-full` grip with no mark then has no width to be, so `content-center` rather than
`place-content-center`.

The `cursor` is the caller's: the axis says which way the grip travels, not what it
bounds.

-}
resize : Axis -> { glyph : String, cursor : String, size : Size, onStep : Steps -> msg } -> Config msg -> Html msg
resize axis look config =
    let
        classes =
            case axis of
                Across ->
                    "grid place-content-center w-2 h-full text-[11px] select-none transition-colors"

                Down ->
                    "grid place-content-center h-2 w-full text-[11px] select-none transition-colors"
    in
    grip
        (Splitter axis)
        { id = config.id
        , label = config.label
        , held = config.held
        , marks = config.marks
        , size = Just look.size
        , hint = keyHint axis
        , classes = classes
        , cursor =
            if config.held then
                "cursor-grabbing"

            else
                look.cursor
        , glyph = look.glyph
        , events = events config ++ [ stepWith bothArrows look.onStep ]
        }


{-| The grip at a corner, growing both sizes at once: the pointer is read along both
axes and the caller decides which of them moves what. Which diagonal it lies along is
the cursor's -- the two ends of it, since a corner pulls both. It fills the box it is set
in, which is what sizes the corner.
-}
corner : Direction -> Config msg -> Html msg
corner direction config =
    grip
        Corner
        { id = config.id
        , label = config.label
        , held = config.held
        , marks = config.marks
        , size = Nothing
        , hint = ""
        , classes = "grid h-full w-full select-none transition-colors"
        , cursor =
            if config.held then
                "cursor-grabbing"

            else
                case direction of
                    NorthWest ->
                        "cursor-nwse-resize"

                    SouthEast ->
                        "cursor-nwse-resize"

                    NorthEast ->
                        "cursor-nesw-resize"

                    SouthWest ->
                        "cursor-nesw-resize"
        , glyph = ""
        , events = events config
        }


{-| What the grip is to a reader: `Carry` moves a thing and answers as a button,
and the `String` is the arrows it answers to; `Splitter` is the bar a size is bounded
by, and says which bar it is; `Corner` is where two of those bars meet, and grows both
sizes at once.

The distinction is the ARIA's: a thing a screen reader is told to press has to do
something when pressed, which a splitter does not.

-}
type Kind
    = Carry String
    | Splitter Axis
    | Corner


{-| What every grip is made of: the a11y attributes, the class, the glyph, and the
events the state machine is driven by -- which are the one thing a grip along a line
and a grip across the page do not share.

`hint` is the arrows the grip answers to. An empty one says no key reaches it, and it
is then no tab stop either.

-}
type alias Grip msg =
    { id : String
    , label : String
    , held : Bool
    , marks : Bool
    , size : Maybe Size
    , hint : String
    , classes : String
    , cursor : String
    , glyph : String
    , events : List (Html.Attribute msg)
    }


{-| Every grip centres its glyph with `place-content` rather than `place-items`: an
implicit row track cannot shrink below the glyph's line box, and `place-items`
centres an item within its own track -- which is nothing at all where the glyph
is taller than the 8px an edge grip is, and the row hangs below the grip.

Every grip is `touch-none`: a finger resting on one would otherwise scroll the page
rather than carry the size it bounds.

-}
grip : Kind -> Grip msg -> Html msg
grip kind g =
    let
        keys =
            not (String.isEmpty g.hint)
    in
    Html.node "drag-handle"
        ([ id g.id
         , attribute "aria-roledescription" "drag handle"
         , attribute "aria-label" g.label
         ]
            ++ (if g.marks then
                    [ title
                        (g.label
                            ++ ": drag it"
                            ++ (if keys then
                                    ", or press " ++ g.hint

                                else
                                    ""
                               )
                        )
                    ]

                else
                    []
               )
            ++ [ class
                    (g.classes
                        ++ " touch-none "
                        ++ g.cursor
                        ++ (if g.held && g.marks then
                                " bg-accent text-accent-foreground"

                            else
                                " text-muted-foreground"
                           )
                    )
               ]
            ++ (if keys then
                    [ attribute "tabindex" "0" ]

                else
                    []
               )
            ++ role kind
            ++ values kind g.size
            ++ g.events
        )
        [ text g.glyph ]


{-| The keys a grip steps along, and nothing else. `preventDefault` because the page
would otherwise scroll under them.
-}
stepWith : Decoder step -> (step -> msg) -> Html.Attribute msg
stepWith decoder toMsg =
    preventDefaultOn "keydown" (Decode.map (\step -> ( toMsg step, True )) decoder)


{-| Which of the two buttons a grip is read by took the pointer up.
-}
whichButton : Decoder Button
whichButton =
    Decode.field "button" Decode.int
        |> Decode.andThen
            (\which ->
                case which of
                    0 ->
                        Decode.succeed Primary

                    2 ->
                        Decode.succeed Secondary

                    _ ->
                        Decode.fail "neither button a grip is read by"
            )


{-| What took the pointer down. Anything that is not a mouse is a surface being touched.
-}
device : Decoder Device
device =
    Decode.field "pointerType" Decode.string
        |> Decode.andThen
            (\what ->
                case what of
                    "mouse" ->
                        Decode.succeed Mouse

                    _ ->
                        Decode.succeed Touch
            )


{-| The four arrow keys, stepping whichever axis each of them lies along, and no other key
reaching the message at all.
-}
arrowKeys : (Steps -> msg) -> Html.Attribute msg
arrowKeys =
    stepWith bothArrows


{-| The pointer's events of a grip: the press, the moves, the release and the taking-back.
The press is taken by the primary button alone.
-}
events : Config msg -> List (Html.Attribute msg)
events config =
    pressAndMoves config
        (primaryButton |> Decode.andThen (\_ -> Decode.map config.onGrab place))


{-| The pointer's events of a surface read in both directions at once, where which button took
the pointer up says which operation the drag is.

The page says what each button starts, which is why one element can carry a box by the left
button and turn a map by the right: the two never cross because each keeps its own pointer id,
and a move goes back to whichever holds it.

-}
eventsByButton :
    { g | held : Bool, onGrab : Button -> Device -> Place -> msg, onMove : Place -> msg, onDrop : Place -> msg, onCancel : Int -> msg }
    -> List (Html.Attribute msg)
eventsByButton config =
    pressAndMoves config
        (Decode.map3 (\which what -> config.onGrab which what) whichButton device place)


{-| The press, the moves, the release and the taking-back -- what every grip answers to, however
the press itself was read.
-}
pressAndMoves :
    { c | held : Bool, onMove : Place -> msg, onDrop : Place -> msg, onCancel : Int -> msg }
    -> Decoder msg
    -> List (Html.Attribute msg)
pressAndMoves config press =
    [ on "pointerdown" press
    , on "pointerup" (Decode.map config.onDrop place)
    , on "pointercancel" (Decode.map config.onCancel pointerId)
    , on "lostpointercapture" (Decode.map config.onCancel pointerId)
    ]
        ++ (if config.held then
                [ on "pointermove" (Decode.map config.onMove place) ]

            else
                []
           )


place : Decoder Place
place =
    Decode.map3 Place pointerId (Decode.field "clientX" Decode.float) (Decode.field "clientY" Decode.float)


{-| The role, and the one attribute the role wants. `aria-orientation` names the bar
the grip is, not the axis it travels along: the grip across a column edge is a
vertical bar dragged sideways.
-}
role : Kind -> List (Html.Attribute msg)
role kind =
    case kind of
        Carry arrows ->
            [ attribute "role" "button"

            -- Said, because arrows move a column without the reader being on the
            -- grip. A splitter's arrows need the focus, and are said in its own
            -- `title`; `aria-keyshortcuts` is for keys that work unfocused.
            , attribute "aria-keyshortcuts" arrows
            ]

        Splitter axis ->
            [ attribute "role" "separator"
            , attribute "aria-orientation"
                (case axis of
                    Across ->
                        "vertical"

                    Down ->
                        "horizontal"
                )
            ]

        Corner ->
            -- A separator still, and one that is neither bar: `aria-orientation` has
            -- no word for a corner.
            [ attribute "role" "separator" ]


{-| What a splitter says about the size it bounds. `aria-valuenow` alone is a number with
no unit, so the same number is said again in words.
-}
values : Kind -> Maybe Size -> List (Html.Attribute msg)
values kind size =
    case ( kind, size ) of
        ( Splitter axis, Just v ) ->
            [ attribute "aria-valuenow" (said v.now)
            , attribute "aria-valuemin" (said v.min)
            , attribute "aria-valuetext" (said v.now ++ " pixels " ++ word axis)
            ]
                ++ (case v.max of
                        Just top ->
                            [ attribute "aria-valuemax" (said top) ]

                        Nothing ->
                            []
                   )

        _ ->
            []


said : Float -> String
said =
    round >> String.fromInt


word : Axis -> String
word axis =
    case axis of
        Across ->
            "wide"

        Down ->
            "tall"


pointerId : Decoder Int
pointerId =
    Decode.field "pointerId" Decode.int


primaryButton : Decoder ()
primaryButton =
    Decode.field "button" Decode.int
        |> Decode.andThen
            (\button ->
                if button == 0 then
                    Decode.succeed ()

                else
                    Decode.fail "not the primary button"
            )


{-| The arrows a grip along an edge answers to, said the way the grip itself is drawn.
-}
keyHint : Axis -> String
keyHint axis =
    case axis of
        Across ->
            "← →"

        Down ->
            "↑ ↓"


{-| Fails on every other key, so that Tab and the rest keep what they do.
-}
leftRight : Decoder Int
leftRight =
    Decode.field "key" Decode.string
        |> Decode.andThen
            (\key ->
                case key of
                    "ArrowLeft" ->
                        Decode.map negate amount

                    "ArrowRight" ->
                        amount

                    _ ->
                        Decode.fail "not a step"
            )


{-| How many steps one press takes: five with Shift, which is the coarse step every
splitter's keys are read with.
-}
amount : Decoder Int
amount =
    Decode.map
        (\coarse ->
            if coarse then
                5

            else
                1
        )
        (Decode.field "shiftKey" Decode.bool)


{-| The same keys, stepping whichever axis each of them lies along.
-}
bothArrows : Decoder Steps
bothArrows =
    Decode.field "key" Decode.string
        |> Decode.andThen
            (\key ->
                case key of
                    "ArrowLeft" ->
                        Decode.map (\n -> { x = negate n, y = 0 }) amount

                    "ArrowRight" ->
                        Decode.map (\n -> { x = n, y = 0 }) amount

                    "ArrowUp" ->
                        Decode.map (\n -> { x = 0, y = negate n }) amount

                    "ArrowDown" ->
                        Decode.map (\n -> { x = 0, y = n }) amount

                    _ ->
                        Decode.fail "not a step"
            )
