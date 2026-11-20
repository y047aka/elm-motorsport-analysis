module Page.Wec.Shift exposing (Model, Msg(..), init, update, carried, holds)

{-| Where a box stood before anything moved it, and the pointer that carries it across
the page in both directions at once.

The box cannot be carried out of the window.
The travel it may take is measured off the box itself when a pointer takes it up, and every
move is clamped to what that leaves: the box's own edges stop at the window's.

@docs Model, Msg, init, update, carried, holds

-}

import Browser.Dom
import Drag.Handle as Handle
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


{-| The two ends of a carry: which pointer holds the box, where it was picked up,
and where the box stood when that happened.
-}
type alias Hold =
    { pointerId : Int
    , pointer : { x : Float, y : Float }
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


{-| Whether a pointer carries the box now, which is what says whether the grip is drawn
held.
-}
carried : Model -> Bool
carried m =
    m.carried /= Nothing


{-| Whether that pointer is the one carrying the box.
-}
holds : Int -> Model -> Bool
holds pointerId m =
    Maybe.map .pointerId m.carried == Just pointerId


type Msg
    = Grab Handle.Place
    | Carry Handle.Place
    | Release Handle.Place
    | Cancel Int
    | Travel Bounds
    | Step Handle.Steps


{-| A box that has gone missing leaves the bounds wide, since a grip on it cannot
be held anyway.

A carry belongs to the pointer that picked it up: a second finger on the box neither
picks it up again nor moves it nor lets it go.

-}
update : String -> Msg -> Model -> ( Model, Cmd Msg )
update boxId msg m =
    case msg of
        Grab place ->
            let
                pointer =
                    { x = place.x, y = place.y }
            in
            case m.carried of
                Just _ ->
                    ( m, Cmd.none )

                Nothing ->
                    ( { m | carried = Just { pointerId = place.id, pointer = pointer, from = { x = m.x, y = m.y } } }
                    , Browser.Dom.getElement boxId
                        |> Task.map (boundsFrom { x = m.x, y = m.y })
                        |> Task.onError (\_ -> Task.succeed unmeasured)
                        |> Task.perform Travel
                    )

        Carry place ->
            case heldBy place.id m.carried of
                Nothing ->
                    ( m, Cmd.none )

                Just hold ->
                    ( { m
                        | x = clamp m.bounds.minX m.bounds.maxX (hold.from.x + place.x - hold.pointer.x)
                        , y = clamp m.bounds.minY m.bounds.maxY (hold.from.y + place.y - hold.pointer.y)
                      }
                    , Cmd.none
                    )

        Release place ->
            ( { m | carried = Maybe.andThen (keptUnless place.id) m.carried }, Cmd.none )

        Cancel id ->
            ( { m | carried = Maybe.andThen (keptUnless id) m.carried }, Cmd.none )

        Travel bounds ->
            ( { m
                | bounds = bounds
                , x = clamp bounds.minX bounds.maxX m.x
                , y = clamp bounds.minY bounds.maxY m.y
              }
            , Cmd.none
            )

        Step steps ->
            ( { m
                | x = clamp m.bounds.minX m.bounds.maxX (m.x + toFloat steps.x * step)
                , y = clamp m.bounds.minY m.bounds.maxY (m.y + toFloat steps.y * step)
              }
            , Cmd.none
            )


{-| The carry, when the pointer named is the one holding the box.
-}
heldBy : Int -> Maybe Hold -> Maybe Hold
heldBy id held =
    case held of
        Just hold ->
            if hold.pointerId == id then
                Just hold

            else
                Nothing

        Nothing ->
            Nothing


{-| The carry let go of, when the pointer named is the one holding it; a second
finger's release leaves the first holding on.
-}
keptUnless : Int -> Hold -> Maybe Hold
keptUnless id hold =
    if hold.pointerId == id then
        Nothing

    else
        Just hold


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
