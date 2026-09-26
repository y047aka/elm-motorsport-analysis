module UI.DragHandle exposing (Pointer, view)

{-| A grip that carries something sideways: by the pointer, or a step at a time
by the arrow keys once it has the focus.

@docs Pointer, view

-}

import Html exposing (Html, text)
import Html.Attributes exposing (attribute, class, id, title)
import Html.Events exposing (on, preventDefaultOn)
import Json.Decode as Decode exposing (Decoder)


{-| Which pointer, and its `clientX`. Two fingers can hold two grips at once, and
each reports its own release.
-}
type alias Pointer =
    { id : Int
    , x : Float
    }


{-| `held` is the caller's, and says whether this grip is the one being carried.
Moves are only reported while it is. The release is reported always, and says
where it happened: a carry let go of before the next frame has reported no
moves at all.

`onCancel` is the carry ending without being let go of: the browser taking the
pointer for itself, or the grip leaving the document. It also follows every
`onDrop`, and both arrive whether or not anything is held.

-}
view :
    { id : String
    , label : String
    , held : Bool
    , onGrab : Pointer -> msg
    , onMove : Pointer -> msg
    , onDrop : Pointer -> msg
    , onCancel : Int -> msg
    , onStep : Int -> msg
    }
    -> Html msg
view config =
    Html.node "drag-handle"
        ([ id config.id
         , attribute "role" "button"
         , attribute "aria-roledescription" "drag handle"
         , attribute "aria-keyshortcuts" "ArrowLeft ArrowRight"
         , attribute "tabindex" "0"
         , attribute "aria-label" config.label
         , title (config.label ++ ": drag it, or press ← →")
         , class
            ("grid place-items-center w-5 h-5 rounded-md text-[11px] select-none transition-colors hover:bg-accent hover:text-accent-foreground"
                ++ (if config.held then
                        " cursor-grabbing bg-accent text-accent-foreground"

                    else
                        " cursor-grab text-muted-foreground"
                   )
            )
         , on "pointerdown" (primaryButton |> Decode.andThen (\_ -> Decode.map config.onGrab pointer))
         , on "pointerup" (Decode.map config.onDrop pointer)
         , on "pointercancel" (Decode.map config.onCancel pointerId)
         , on "lostpointercapture" (Decode.map config.onCancel pointerId)
         , preventDefaultOn "keydown" (Decode.map (\step -> ( config.onStep step, True )) arrowStep)
         ]
            ++ (if config.held then
                    [ on "pointermove" (Decode.map config.onMove pointer) ]

                else
                    []
               )
        )
        [ text "⠿" ]


pointer : Decoder Pointer
pointer =
    Decode.map2 Pointer pointerId (Decode.field "clientX" Decode.float)


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
arrowStep : Decoder Int
arrowStep =
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
