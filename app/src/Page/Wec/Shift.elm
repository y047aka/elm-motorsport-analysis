module Page.Wec.Shift exposing (Model, Msg(..), init, update, handle)

{-| Where a box stood before anything moved it, and the grip that carries it across
the page in both directions at once.

The box cannot be carried out of the window.
The travel it may take is measured off the box itself when the grip is picked up, and every move is clamped to what that leaves: the box's own edges stop at the window's.

@docs Model, Msg, init, update, handle

-}

import Browser.Dom
import Drag.Handle as Handle exposing (Axis)
import Html exposing (Html, text)
import Html.Attributes exposing (attribute, class, id, title)
import Html.Events exposing (on, preventDefaultOn)
import Json.Decode as Decode exposing (Decoder)
import Task


{-| How far the box has been taken from where it is stood, and whether a pointer
holds it now. `bounds` is what the last pick measured; `unmeasured` is what it holds
before any pick has happened, and after one whose read failed.
-}
type alias Model =
    { x : Float
    , y : Float
    , carried : Maybe Hold
    , bounds : Bounds
    }


{-| The two ends of a carry: where the pointer was picked up, and where the box
stood when that happened.
-}
type alias Hold =
    { pointer : { x : Float, y : Float }
    , from : { x : Float, y : Float }
    }


{-| How far the box may go along each axis from where it is stood, the four of them
measured so its own edges land on the window's.
-}
type alias Bounds =
    { minX : Float
    , maxX : Float
    , minY : Float
    , maxY : Float
    }


unmeasured : Bounds
unmeasured =
    { minX = -4000, maxX = 4000, minY = -4000, maxY = 4000 }


init : Model
init =
    { x = 0
    , y = 0
    , carried = Nothing
    , bounds = unmeasured
    }


type Msg
    = Grab { x : Float, y : Float }
    | Carry { x : Float, y : Float }
    | Release
    | Cancel
    | Travel Bounds
    | Step Axis Int


{-| A box that has gone missing leaves the bounds wide, since a grip on it cannot
be held anyway.
-}
update : String -> Msg -> Model -> ( Model, Cmd Msg )
update boxId msg m =
    case msg of
        Grab pointer ->
            ( { m | carried = Just { pointer = pointer, from = { x = m.x, y = m.y } } }
            , Browser.Dom.getElement boxId
                |> Task.map (boundsFrom { x = m.x, y = m.y })
                |> Task.onError (\_ -> Task.succeed unmeasured)
                |> Task.perform Travel
            )

        Carry pointer ->
            case m.carried of
                Nothing ->
                    ( m, Cmd.none )

                Just carry ->
                    ( { m
                        | x = clamp m.bounds.minX m.bounds.maxX (carry.from.x + pointer.x - carry.pointer.x)
                        , y = clamp m.bounds.minY m.bounds.maxY (carry.from.y + pointer.y - carry.pointer.y)
                      }
                    , Cmd.none
                    )

        Release ->
            ( { m | carried = Nothing }, Cmd.none )

        Cancel ->
            ( { m | carried = Nothing }, Cmd.none )

        Travel bounds ->
            ( { m
                | bounds = bounds
                , x = clamp bounds.minX bounds.maxX m.x
                , y = clamp bounds.minY bounds.maxY m.y
              }
            , Cmd.none
            )

        Step axis steps ->
            let
                d =
                    toFloat steps * step
            in
            case axis of
                Handle.Across ->
                    ( { m | x = clamp m.bounds.minX m.bounds.maxX (m.x + d) }, Cmd.none )

                Handle.Down ->
                    ( { m | y = clamp m.bounds.minY m.bounds.maxY (m.y + d) }, Cmd.none )


{-| The four shifts the window leaves a box, said in the shift's own units rather
than as travel from wherever the pointer happened to be picked up: the corner the box
is stood at is recovered from the measurement by taking back the shift it was read
under, so the bounds say the same thing at every pick and between picks too.

`Browser.Dom.getElement` puts `viewport.x` and `viewport.y` at how far the page has
been scrolled, so `element.x` without them is where the box stands within the window.

-}
boundsFrom : { x : Float, y : Float } -> Browser.Dom.Element -> Bounds
boundsFrom { x, y } { element, viewport } =
    let
        anchorX =
            element.x - viewport.x - x

        anchorY =
            element.y - viewport.y - y
    in
    { minX = negate anchorX
    , maxX = viewport.width - element.width - anchorX
    , minY = negate anchorY
    , maxY = viewport.height - element.height - anchorY
    }


step : Float
step =
    20


{-| The grip a box is carried by: the pointer held by `drag-handle`, the arrow keys
once it has the focus.
-}
handle : String -> Model -> Html Msg
handle gripId m =
    Html.node "drag-handle"
        ([ id gripId
         , attribute "role" "button"
         , attribute "aria-roledescription" "drag handle"
         , attribute "tabindex" "0"
         , attribute "aria-label" "Move the floating track map"
         , title "Move the floating track map: drag it, or press ← → ↑ ↓"
         , attribute "aria-keyshortcuts" "ArrowLeft ArrowRight ArrowUp ArrowDown"
         , class
            ("grid place-items-center w-5 h-5 rounded-md text-[11px] select-none transition-colors hover:bg-accent hover:text-accent-foreground "
                ++ (if m.carried /= Nothing then
                        "cursor-grabbing"

                    else
                        "cursor-grab"
                   )
            )
         , on "pointerdown" press
         , on "pointerup" (Decode.succeed Release)
         , on "pointercancel" (Decode.succeed Cancel)
         , on "lostpointercapture" (Decode.succeed Cancel)
         , preventDefaultOn "keydown" keys
         ]
            ++ moves m
        )
        [ text "⠿" ]


moves : Model -> List (Html.Attribute Msg)
moves m =
    if m.carried /= Nothing then
        [ on "pointermove" position ]

    else
        []


press : Decoder Msg
press =
    Decode.field "button" Decode.int
        |> Decode.andThen
            (\button ->
                if button == 0 then
                    Decode.map Grab (pair "clientX" "clientY")

                else
                    Decode.fail "not the primary button"
            )


position : Decoder Msg
position =
    Decode.map Carry (pair "clientX" "clientY")


pair : String -> String -> Decoder { x : Float, y : Float }
pair x y =
    Decode.map2 (\a b -> { x = a, y = b }) (Decode.field x Decode.float) (Decode.field y Decode.float)


keys : Decoder ( Msg, Bool )
keys =
    Decode.field "key" Decode.string
        |> Decode.andThen
            (\key ->
                case key of
                    "ArrowLeft" ->
                        Decode.succeed ( Step Handle.Across -1, True )

                    "ArrowRight" ->
                        Decode.succeed ( Step Handle.Across 1, True )

                    "ArrowUp" ->
                        Decode.succeed ( Step Handle.Down -1, True )

                    "ArrowDown" ->
                        Decode.succeed ( Step Handle.Down 1, True )

                    _ ->
                        Decode.succeed ( Step Handle.Across 0, False )
            )
