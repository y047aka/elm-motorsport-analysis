module Drag.Handle exposing (Axis(..), Direction(..), Pointer, Place, Steps, Config, Stepped, Config2, Placed, resize, corner, view, carry)

{-| A grip that carries something: along a line, or across the page in both directions at
once -- by the pointer, or a step at a time by the arrow keys for the grips that
answer to them.

The grip holds no state of its own -- `held` is the caller's, and the carry
behind it is `Drag`'s business. What the grip adds is the pointer's path: the
`drag-handle` custom element calls `setPointerCapture`, which Elm cannot, so every move and the release come back to the grip even once the pointer has left
it.

@docs Axis, Direction, Pointer, Place, Steps, Config, Stepped, Config2, Placed, resize, corner, view, carry

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


{-| Which pointer, and where it is along the axis its grip reads. Two fingers can
hold two grips at once, and each reports its own release.
-}
type alias Pointer =
    { id : Int
    , along : Float
    }


{-| Which corner of a box a grip stands at. It says which way the box grows, and so
which way the cursor turns: the two corners of one diagonal share a cursor.
-}
type Direction
    = NorthWest
    | NorthEast
    | SouthWest
    | SouthEast


{-| Which pointer, and where it is in both directions at once: what the grip that
carries a box across the page reads.
-}
type alias Place =
    { id : Int
    , x : Float
    , y : Float
    }


{-| How many steps the arrow keys took a thing along each axis. The keys come one at
a time, so a caller never sees both moved.
-}
type alias Steps =
    { x : Int
    , y : Int
    }


{-| A grip's own state is the caller's: `held` says whether this grip is the
one being carried, and moves are only reported while it is. The release is
reported always, and says where it happened: a carry let go of before the
next frame has reported no moves at all.

`onCancel` is the carry ending without being let go of: the browser taking
the pointer for itself, or the grip leaving the document. It also follows
every `onDrop`, and both arrive whether or not anything is held.

-}
type alias Config msg =
    { id : String
    , label : String
    , held : Bool
    , onGrab : Pointer -> msg
    , onMove : Pointer -> msg
    , onDrop : Pointer -> msg
    , onCancel : Int -> msg
    }


{-| The same, for a grip the arrow keys step once it has the focus. The step comes
for every other key as nothing.
-}
type alias Stepped msg =
    { id : String
    , label : String
    , held : Bool
    , onGrab : Pointer -> msg
    , onMove : Pointer -> msg
    , onDrop : Pointer -> msg
    , onCancel : Int -> msg
    , onStep : Int -> msg
    }


{-| The same, for a grip that reads both directions at once and answers to no keys.
-}
type alias Placed msg =
    { id : String
    , label : String
    , held : Bool
    , onGrab : Place -> msg
    , onMove : Place -> msg
    , onDrop : Place -> msg
    , onCancel : Int -> msg
    }


{-| The same, for the grip that carries a thing across the page: both directions
are read, and the arrow keys step both. The pointer still arrives with its id, and
a carry belongs to the pointer that picked it up.
-}
type alias Config2 msg =
    { id : String
    , label : String
    , held : Bool
    , onGrab : Place -> msg
    , onMove : Place -> msg
    , onDrop : Place -> msg
    , onCancel : Int -> msg
    , onStep : Steps -> msg
    }


{-| The grip for carrying a thing along.
-}
view : Stepped msg -> Html msg
view config =
    grip
        (Carry "ArrowLeft ArrowRight")
        { id = config.id
        , label = config.label
        , held = config.held
        , hint = "← →"
        , classes = "grid place-content-center w-5 h-5 rounded-md text-[11px] select-none transition-colors hover:bg-accent hover:text-accent-foreground"
        , cursor =
            if config.held then
                "cursor-grabbing"

            else
                "cursor-grab"
        , glyph = "⠿"
        , events = eventsAlong Across config ++ [ stepWith leftRight config.onStep ]
        }


{-| The grip for carrying a thing across the page, in both directions at once.
-}
carry : Config2 msg -> Html msg
carry config =
    grip
        (Carry "ArrowLeft ArrowRight ArrowUp ArrowDown")
        { id = config.id
        , label = config.label
        , held = config.held
        , hint = "← → ↑ ↓"
        , classes = "grid place-content-center w-5 h-5 rounded-md text-[11px] select-none transition-colors hover:bg-accent hover:text-accent-foreground"
        , cursor =
            if config.held then
                "cursor-grabbing"

            else
                "cursor-grab"
        , glyph = "⠿"
        , events = eventsAcross config ++ [ stepWith bothArrows config.onStep ]
        }


{-| The same grip lying along an edge to resize what it bounds: the pointer's
travel is the size's, and no key reaches it. `Across` lies along a column
edge, `Down` along a row edge. It answers as the splitter it is, and how far the
size can go is said nowhere on the element.

The `String` is the mark drawn along the edge. An empty one leaves the cursor the
only thing saying where the grip is -- and asks the wrapper to centre along the
mark's own axis only: `justify-content: center` sizes a track to its content, and a
`w-full` grip with no mark then has no width to be, so `content-center` rather than
`place-content-center`.

-}
resize : Axis -> String -> Config msg -> Html msg
resize axis glyph config =
    let
        ( classes, cursor ) =
            case axis of
                Across ->
                    ( "grid place-content-center w-2 h-full text-[11px] select-none transition-colors"
                    , "cursor-col-resize"
                    )

                Down ->
                    ( "grid place-content-center h-2 w-full text-[11px] select-none transition-colors"
                    , "cursor-row-resize"
                    )
    in
    grip
        (Splitter axis)
        { id = config.id
        , label = config.label
        , held = config.held
        , hint = ""
        , classes = classes
        , cursor =
            if config.held then
                "cursor-grabbing"

            else
                cursor
        , glyph = glyph
        , events = eventsAlong axis config
        }


{-| The grip at a corner, growing both sizes at once: the pointer is read along both
axes and the caller decides which of them moves what. Which diagonal it lies along is
the cursor's.
-}
corner : Direction -> Placed msg -> Html msg
corner direction config =
    grip
        Corner
        { id = config.id
        , label = config.label
        , held = config.held
        , hint = ""
        , classes = "grid h-2.5 w-2.5 select-none transition-colors"
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
        , events = eventsAcross config
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
         , title
            (g.label
                ++ ": drag it"
                ++ (if keys then
                        ", or press " ++ g.hint

                    else
                        ""
                   )
            )
         , class
            (g.classes
                ++ " "
                ++ g.cursor
                ++ (if g.held then
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
            ++ g.events
        )
        [ text g.glyph ]


{-| The keys a grip steps along, and nothing else. `preventDefault` because the page
would otherwise scroll under them.
-}
stepWith : Decoder step -> (step -> msg) -> Html.Attribute msg
stepWith decoder toMsg =
    preventDefaultOn "keydown" (Decode.map (\step -> ( toMsg step, True )) decoder)


{-| The pointer's events of a grip read along one axis. A move is listened for only
while one is held, and the release is listened for always: the pointer can be let go
of before the frame that would have added a move.

The row stays open because the grip that steps along the axis is handed over too, and
its `onStep` is the grip's own business.

-}
eventsAlong :
    Axis
    -> { g | held : Bool, onGrab : Pointer -> msg, onMove : Pointer -> msg, onDrop : Pointer -> msg, onCancel : Int -> msg }
    -> List (Html.Attribute msg)
eventsAlong axis config =
    let
        read =
            pointer axis
    in
    [ on "pointerdown" (primaryButton |> Decode.andThen (\_ -> Decode.map config.onGrab read))
    , on "pointerup" (Decode.map config.onDrop read)
    , on "pointercancel" (Decode.map config.onCancel pointerId)
    , on "lostpointercapture" (Decode.map config.onCancel pointerId)
    ]
        ++ (if config.held then
                [ on "pointermove" (Decode.map config.onMove read) ]

            else
                []
           )


{-| The pointer's events of a grip read in both directions at once. The row stays open
because the corner grip reads the same pointer and answers to no keys.
-}
eventsAcross :
    { g | held : Bool, onGrab : Place -> msg, onMove : Place -> msg, onDrop : Place -> msg, onCancel : Int -> msg }
    -> List (Html.Attribute msg)
eventsAcross config =
    [ on "pointerdown" (primaryButton |> Decode.andThen (\_ -> Decode.map config.onGrab place))
    , on "pointerup" (Decode.map config.onDrop place)
    , on "pointercancel" (Decode.map config.onCancel pointerId)
    , on "lostpointercapture" (Decode.map config.onCancel pointerId)
    ]
        ++ (if config.held then
                [ on "pointermove" (Decode.map config.onMove place) ]

            else
                []
           )


pointer : Axis -> Decoder Pointer
pointer axis =
    Decode.map2 Pointer pointerId (coordinate axis)


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
            -- grip. A splitter answers to no keys at all, and `aria-keyshortcuts` is
            -- for keys that work unfocused.
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


coordinate : Axis -> Decoder Float
coordinate axis =
    Decode.field
        (case axis of
            Across ->
                "clientX"

            Down ->
                "clientY"
        )
        Decode.float


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


{-| Fails on every other key, so that Tab and the rest keep what they do.
-}
leftRight : Decoder Int
leftRight =
    Decode.field "key" Decode.string
        |> Decode.andThen
            (\key ->
                case key of
                    "ArrowLeft" ->
                        Decode.succeed -1

                    "ArrowRight" ->
                        Decode.succeed 1

                    _ ->
                        Decode.fail "not a step"
            )


{-| The same keys, stepping whichever axis each of them lies along.
-}
bothArrows : Decoder Steps
bothArrows =
    Decode.field "key" Decode.string
        |> Decode.andThen
            (\key ->
                case key of
                    "ArrowLeft" ->
                        Decode.succeed { x = -1, y = 0 }

                    "ArrowRight" ->
                        Decode.succeed { x = 1, y = 0 }

                    "ArrowUp" ->
                        Decode.succeed { x = 0, y = -1 }

                    "ArrowDown" ->
                        Decode.succeed { x = 0, y = 1 }

                    _ ->
                        Decode.fail "not a step"
            )
