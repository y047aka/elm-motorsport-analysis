module Drag.Handle exposing (Axis(..), Pointer, Config, resize, view)

{-| A grip that carries something along a line: by the pointer, or a step at a
time by the arrow keys once it has the focus.

The grip holds no state of its own -- `held` is the caller's, and the carry
behind it is `Drag`'s business. What the grip adds is the pointer's path: the
`drag-handle` custom element calls `setPointerCapture`, which Elm cannot, so
every move and the release come back to the grip even once the pointer has left
it.

@docs Axis, Pointer, Config, resize, view

-}

import Html exposing (Html, text)
import Html.Attributes exposing (attribute, class, id, title)
import Html.Events exposing (on, preventDefaultOn)
import Json.Decode as Decode exposing (Decoder)


{-| The axis a grip reads the pointer along, and steps along with the arrow
keys: `Across` is `clientX` and ← →, `Down` is `clientY` and ↑ ↓.
-}
type Axis
    = Across
    | Down


{-| Which pointer, and where it is along the axis its grip reads -- `clientX`
for an `Across` grip, `clientY` for a `Down` one. Two fingers can hold two
grips at once, and each reports its own release.
-}
type alias Pointer =
    { id : Int
    , along : Float
    }


{-| A grip's own state is the caller's: `held` says whether this grip is the
one being carried, and moves are only reported while it is. The release is
reported always, and says where it happened: a carry let go of before the
next frame has reported no moves at all.

`onCancel` is the carry ending without being let go of: the browser taking
the pointer for itself, or the grip leaving the document. It also follows
every `onDrop`, and both arrive whether or not anything is held.

`onStep` is for the arrow keys once the grip has the focus, and arrives for
every other key as nothing.

-}
type alias Config msg =
    { id : String
    , label : String
    , held : Bool
    , onGrab : Pointer -> msg
    , onMove : Pointer -> msg
    , onDrop : Pointer -> msg
    , onCancel : Int -> msg
    , onStep : Int -> msg
    }


{-| The grip for carrying a thing along.
-}
view : Config msg -> Html msg
view config =
    grip
        Across
        config
        "grid place-items-center w-5 h-5 rounded-md text-[11px] select-none transition-colors hover:bg-accent hover:text-accent-foreground"
        (if config.held then
            "cursor-grabbing"

         else
            "cursor-grab"
        )
        "⠿"


{-| The same grip lying along an edge to resize what it bounds: the pointer's
travel is the size's, and the arrow keys step it. `Across` lies along a column
edge, `Down` along a row edge.
-}
resize : Axis -> Config msg -> Html msg
resize axis config =
    let
        ( classes, cursor, glyph ) =
            case axis of
                Across ->
                    ( "grid place-items-center w-2 h-full text-[11px] select-none transition-colors hover:bg-accent hover:text-accent-foreground"
                    , "cursor-col-resize"
                    , "⋮"
                    )

                Down ->
                    ( "grid place-content-center h-2 w-full text-[11px] select-none transition-colors hover:bg-accent hover:text-accent-foreground"
                    , "cursor-row-resize"
                    , "⋯"
                    )
    in
    grip
        axis
        config
        classes
        (if config.held then
            "cursor-grabbing"

         else
            cursor
        )
        glyph


{-| The markup every grip is made of: a `drag-handle` with the aria and data
attributes the contract test reads, the pointer events the state machine is
driven by, and a glyph. Which end of the pointer it reads is the `Axis`.

The row grip passes `place-content-center`, not `place-items-center`: an implicit
row track cannot shrink below the glyph's line box, and a track taller than the
8px that grip is high starts at its top -- `place-items` centers an item within
its track, so it centers nothing and the glyph hangs below the grip.
`place-content` centers the track itself, and the overflow splits evenly.

-}
grip : Axis -> Config msg -> String -> String -> String -> Html msg
grip axis config classes cursor glyph =
    Html.node "drag-handle"
        ([ id config.id
         , attribute "role" "button"
         , attribute "aria-roledescription" "drag handle"
         , attribute "aria-keyshortcuts" (keyShortcuts axis)
         , attribute "tabindex" "0"
         , attribute "aria-label" config.label
         , title (config.label ++ ": drag it, or press " ++ arrowHint axis)
         , class
            (classes
                ++ " "
                ++ cursor
                ++ (if config.held then
                        " bg-accent text-accent-foreground"

                    else
                        " text-muted-foreground"
                   )
            )
         , on "pointerdown" (primaryButton |> Decode.andThen (\_ -> Decode.map config.onGrab (pointer axis)))
         , on "pointerup" (Decode.map config.onDrop (pointer axis))
         , on "pointercancel" (Decode.map config.onCancel pointerId)
         , on "lostpointercapture" (Decode.map config.onCancel pointerId)
         , preventDefaultOn "keydown" (Decode.map (\step -> ( config.onStep step, True )) (arrowStep axis))
         ]
            ++ (if config.held then
                    [ on "pointermove" (Decode.map config.onMove (pointer axis)) ]

                else
                    []
               )
        )
        [ text glyph ]


pointer : Axis -> Decoder Pointer
pointer axis =
    Decode.map2 Pointer pointerId (coordinate axis)


{-| The pointer's position along the axis the grip reads.
-}
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


keyShortcuts : Axis -> String
keyShortcuts axis =
    case axis of
        Across ->
            "ArrowLeft ArrowRight"

        Down ->
            "ArrowUp ArrowDown"


arrowHint : Axis -> String
arrowHint axis =
    case axis of
        Across ->
            "← →"

        Down ->
            "↑ ↓"


{-| Fails on every other key, so that Tab and the rest keep what they do. Which
key steps back and which steps on are the axis's own, so a step goes the same
way a drag does.
-}
arrowStep : Axis -> Decoder Int
arrowStep axis =
    Decode.field "key" Decode.string
        |> Decode.andThen
            (\key ->
                case ( axis, key ) of
                    ( Across, "ArrowLeft" ) ->
                        Decode.succeed -1

                    ( Across, "ArrowRight" ) ->
                        Decode.succeed 1

                    ( Down, "ArrowUp" ) ->
                        Decode.succeed -1

                    ( Down, "ArrowDown" ) ->
                        Decode.succeed 1

                    _ ->
                        Decode.fail "not a step"
            )
