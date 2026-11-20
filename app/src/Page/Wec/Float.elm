module Page.Wec.Float exposing (Model, Msg(..), init, update, view, trigger)

{-| The track map floated over the columns: hidden until the tracker column's `◱`
asks for it, sized by a grip along each of its four edges and at each of its four corners, carried by a fifth, and taking part in none of the strip's grid.

The box is a `popover`, and a `manual` one: the browser keeps whether it is open, the two presses only name it, and nothing here can be closed by a press outside it -- the columns are worked while the map is up.

The camera belongs here: this is the one drawing raised off the ground it was surveyed on.

@docs Model, Msg, init, update, view, trigger

-}

import Drag.Handle as Handle
import Html exposing (Html, div, text)
import Html.Attributes as Attributes exposing (attribute)
import Html.Events exposing (on)
import Json.Decode as Decode
import Motorsport.Chart.Tracker exposing (Track)
import Motorsport.Chart.Tracker3d as Track3d
import Motorsport.Race.Snapshot exposing (Snapshot)
import Page.Wec.Columns as Columns
import Page.Wec.Resize as Resize
import Page.Wec.Shift as Shift
import View.CarDetail.Header as Header
import View.TrackMap3d as TrackMap3d


type alias Model =
    { shown : Bool
    , width : Resize.Model
    , height : Resize.Model
    , shift : Shift.Model
    , camera : Track3d.Model
    }


init : Model
init =
    { shown = False
    , width = Resize.init defaultWidth
    , height = Resize.init defaultHeight
    , shift = Shift.init
    , camera = Track3d.init
    }


{-| `Shown` mirrors what the popover said of itself; the presses themselves are the
browser's, and reach no message at all.
-}
type Msg
    = Shown Bool
    | LeftMsg Resize.Msg
    | RightMsg Resize.Msg
    | TopMsg Resize.Msg
    | BottomMsg Resize.Msg
    | GrabCorner Handle.Direction Handle.Place
    | CarryCorner Handle.Direction Handle.Place
    | DropCorner Handle.Direction Handle.Place
    | CancelCorner Handle.Direction Int
    | ShiftMsg Shift.Msg
    | CameraMsg Track3d.Msg


{-| The box the floating map opens at.
480 by 180 is `Tracker3d.box`'s own three to one once the card's 32px of padding is gone, and a box of that shape is the one the drawing fills exactly; letterboxing is what a box of another proportion costs.
The map is stood at the bottom right of the page, and every one of its four edges is a grip: the two away from the corner it is stood at grow `AgainstPointer`, and the two at it are `WithPointer` and take the box along with the size, so the edge opposite the one held stays where it was.
-}
defaultWidth : Float
defaultWidth =
    480


defaultHeight : Float
defaultHeight =
    180


widthFence : Resize.Fence
widthFence =
    { min = 280
    , max = 960
    }


heightFence : Resize.Fence
heightFence =
    { min = 120
    , max = 480
    }


{-| The room between the corner the box is stood at and the window's: the box's own
`bottom-2.5 right-2.5`, since a popover in the top layer is inset from the _viewport_
and not from `mainGrid` -- the same reason `inset: 0` is answered with `top-auto
left-auto`. The two grips at the anchored edges grow the box along it, and stop there:
the box's own edges stop at the window's, as they do under a carry.
-}
cornerRoom : Float
cornerRoom =
    10


{-| An edge the box keeps a size by, and whether the box is anchored at it. The box is
stood at its bottom right, so those two edges grow into the room the corner left and
take the box along with the size; the other two grow away from a box that stays where it
stands.
-}
type alias Side =
    { anchored : Bool
    , edge : Resize.Edge
    }


left : Side
left =
    { anchored = False
    , edge =
        { axis = Handle.Across
        , grows = Resize.AgainstPointer
        , fence = widthFence
        , id = "tracker-float-left-grip"
        , label = "Resize the floating track map from the left"
        , glyph = ""
        }
    }


right : Side
right =
    { anchored = True
    , edge =
        { axis = Handle.Across
        , grows = Resize.WithPointer
        , fence = widthFence
        , id = "tracker-float-right-grip"
        , label = "Resize the floating track map from the right"
        , glyph = ""
        }
    }


top : Side
top =
    { anchored = False
    , edge =
        { axis = Handle.Down
        , grows = Resize.AgainstPointer
        , fence = heightFence
        , id = "tracker-float-top-grip"
        , label = "Resize the floating track map from the top"
        , glyph = ""
        }
    }


bottom : Side
bottom =
    { anchored = True
    , edge =
        { axis = Handle.Down
        , grows = Resize.WithPointer
        , fence = heightFence
        , id = "tracker-float-bottom-grip"
        , label = "Resize the floating track map from the bottom"
        , glyph = ""
        }
    }


{-| The corner grips. A corner is the meeting of two edges and grows both sizes at
once, so it holds both under one id, and that id is what the two sizes are then said to
be held by.

`at` is where the grip stands, outside the box by the same 10px the edge grips stand out
by.

-}
type alias Corner =
    { id : String
    , label : String
    , at : String
    , width : Side
    , height : Side
    }


corner : Handle.Direction -> Corner
corner direction =
    case direction of
        Handle.NorthWest ->
            { id = "tracker-float-top-left-grip"
            , label = "Resize the floating track map from its top-left corner"
            , at = "-top-2.5 -left-2.5"
            , width = left
            , height = top
            }

        Handle.NorthEast ->
            { id = "tracker-float-top-right-grip"
            , label = "Resize the floating track map from its top-right corner"
            , at = "-top-2.5 -right-2.5"
            , width = right
            , height = top
            }

        Handle.SouthWest ->
            { id = "tracker-float-bottom-left-grip"
            , label = "Resize the floating track map from its bottom-left corner"
            , at = "-bottom-2.5 -left-2.5"
            , width = left
            , height = bottom
            }

        Handle.SouthEast ->
            { id = "tracker-float-bottom-right-grip"
            , label = "Resize the floating track map from its bottom-right corner"
            , at = "-bottom-2.5 -right-2.5"
            , width = right
            , height = bottom
            }


{-| `boxId` is what the travel is measured against at every pick, and what both
presses point their `popovertarget` at.
-}
box : Shift.Box
box =
    { boxId = "tracker-float-box"
    , gripId = "tracker-float-move-grip"
    , label = "Move the floating track map"
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg m =
    case msg of
        Shown shown ->
            ( { m | shown = shown }, Cmd.none )

        LeftMsg sub ->
            let
                grown =
                    grow left.edge.id left sub m.width m.shift.x
            in
            ( { m | width = grown.size }, Cmd.none )

        RightMsg sub ->
            let
                grown =
                    grow right.edge.id right sub m.width m.shift.x

                shift =
                    m.shift
            in
            ( { m | width = grown.size, shift = { shift | x = grown.shift } }, Cmd.none )

        TopMsg sub ->
            let
                grown =
                    grow top.edge.id top sub m.height m.shift.y
            in
            ( { m | height = grown.size }, Cmd.none )

        BottomMsg sub ->
            let
                grown =
                    grow bottom.edge.id bottom sub m.height m.shift.y

                shift =
                    m.shift
            in
            ( { m | height = grown.size, shift = { shift | y = grown.shift } }, Cmd.none )

        GrabCorner direction place ->
            ( growCorner direction Resize.Grab place m, Cmd.none )

        CarryCorner direction place ->
            ( growCorner direction Resize.Carrying place m, Cmd.none )

        DropCorner direction place ->
            ( growCorner direction Resize.Release place m, Cmd.none )

        CancelCorner direction pointerId ->
            let
                c =
                    corner direction
            in
            ( { m
                | width = Resize.update c.width.edge (Resize.Cancel pointerId) m.width
                , height = Resize.update c.height.edge (Resize.Cancel pointerId) m.height
              }
            , Cmd.none
            )

        ShiftMsg sub ->
            let
                ( shift, cmd ) =
                    Shift.update box sub m.shift
            in
            ( { m | shift = shift }, Cmd.map ShiftMsg cmd )

        CameraMsg sub ->
            ( { m | camera = Track3d.update sub m.camera }, Cmd.none )


{-| One axis of a drag on a size, by the grip named `gripId`. The two edges the box is
anchored at grow into the room the corner left of the window, and take the box along by
the same travel the size grew -- the edge opposite the grip held stays where it was, and
the ceiling is the same at every move of one drag because size and shift both grow.

The other two leave the box stood and are bounded by nothing but their `Fence`.

-}
grow : String -> Side -> Resize.Msg -> Resize.Model -> Float -> { size : Resize.Model, shift : Float }
grow gripId side msg model shift =
    let
        base =
            side.edge

        edge =
            { base | id = gripId }

        size =
            Resize.update
                (if side.anchored then
                    Resize.cappedTo (model.size + cornerRoom - shift) edge

                 else
                    edge
                )
                msg
                model
    in
    { size = size
    , shift =
        if side.anchored then
            shift + size.size - model.size

        else
            shift
    }


{-| One pointer event of a corner, read along both axes and applied to both sizes it
holds: each axis does on its own what it would do to one edge grip.
-}
growCorner : Handle.Direction -> (Handle.Pointer -> Resize.Msg) -> Handle.Place -> Model -> Model
growCorner direction toMsg place m =
    let
        c =
            corner direction

        width =
            grow c.id c.width (toMsg { id = place.id, along = place.x }) m.width m.shift.x

        height =
            grow c.id c.height (toMsg { id = place.id, along = place.y }) m.height m.shift.y

        shift =
            m.shift
    in
    { m | width = width.size, height = height.size, shift = { shift | x = width.shift, y = height.shift } }


{-| The map floated over the columns, drawn into the card the page hands it.

The box stands on the page whether or not it is open -- a `popovertarget` resolves by id, so the element has to be there to be shown -- and the UA keeps a closed popover out of layout. What is not built while it is closed is the drawing itself, which is recomputed every frame of the race.

It is a child of `mainGrid` and not of the strip, whose offsets are read against `mainGrid`'s padding box, so `bottom-2.5 right-2.5` is what stands it on the same edge the columns end at. `card-elements.ts` owns every class the card itself has, which leaves the wrapper the one thing here that can carry a surface.

Three of the UA's popover sheet reach this box and each is answered: `inset: 0` by `top-auto left-auto`, `overflow: auto` by `overflow-visible` because the four size grips stand outside the box, and `display: none` by `hidden [&:popover-open]:grid` -- the box needs `grid` to lay its card out, and an author `display` silently wins over the UA's hiding of a closed popover.

-}
view : Model -> (Html Msg -> List (Html Msg) -> Html Msg) -> Track -> Snapshot -> Html Msg
view m frame track snapshot =
    let
        -- A corner grows both sizes, so it is drawn held when either of them says it
        -- holds -- and it is then the one the moves come back to.
        cornerGrip direction =
            let
                c =
                    corner direction
            in
            div [ Attributes.class ("absolute " ++ c.at ++ " z-20") ]
                [ Handle.corner direction
                    { id = c.id
                    , label = c.label
                    , held = m.width.grip == Just c.id || m.height.grip == Just c.id
                    , onGrab = GrabCorner direction
                    , onMove = CarryCorner direction
                    , onDrop = DropCorner direction
                    , onCancel = \pointerId -> CancelCorner direction pointerId
                    }
                ]
    in
    div
        [ Attributes.id box.boxId
        , attribute "popover" "manual"
        , Attributes.class "absolute top-auto left-auto bottom-2.5 right-2.5 overflow-visible hidden [&:popover-open]:grid rounded-xl bg-background/80 text-popover-foreground backdrop-blur-lg border border-border shadow-glass"
        , Attributes.style "width" (Columns.px m.width.size)
        , Attributes.style "height" (Columns.px m.height.size)
        , Attributes.style "transform" ("translate(" ++ Columns.px m.shift.x ++ ", " ++ Columns.px m.shift.y ++ ")")
        , on "toggle" toggled
        , attribute "data-tracker-float" ""
        ]
        [ frame
            (if m.shown then
                surface m track snapshot

             else
                text ""
            )
            [ Html.map ShiftMsg (Shift.handle box m.shift), closer ]
        , div [ Attributes.class "absolute -left-2.5 top-0 z-10 grid h-full w-2.5 place-items-center" ]
            [ Html.map LeftMsg (Resize.grip left.edge m.width) ]
        , div [ Attributes.class "absolute -right-2.5 top-0 z-10 grid h-full w-2.5 place-items-center" ]
            [ Html.map RightMsg (Resize.grip right.edge m.width) ]
        , div [ Attributes.class "absolute -top-2.5 left-0 z-10 grid h-2.5 w-full content-center" ]
            [ Html.map TopMsg (Resize.grip top.edge m.height) ]
        , div [ Attributes.class "absolute -bottom-2.5 left-0 z-10 grid h-2.5 w-full content-center" ]
            [ Html.map BottomMsg (Resize.grip bottom.edge m.height) ]
        , cornerGrip Handle.NorthWest
        , cornerGrip Handle.NorthEast
        , cornerGrip Handle.SouthWest
        , cornerGrip Handle.SouthEast
        ]


toggled : Decode.Decoder Msg
toggled =
    Decode.field "newState" Decode.string
        |> Decode.map (\state -> Shown (state == "open"))


surface : Model -> Track -> Snapshot -> Html Msg
surface m track snapshot =
    TrackMap3d.surface { model = m.camera, toMsg = CameraMsg, track = track, snapshot = snapshot }


{-| The press that floats the map over the columns, standing in the tracker
column's corner and staying `◱` however many times it is pressed.
-}
trigger : Html Msg
trigger =
    Header.cornerPopover
        { popover = box.boxId
        , action = "show"
        , label = "Float the track map over the columns"
        , glyph = "◱"
        }


{-| The ✕ in the map's own corner. It is the only way back, which is why the
popover is `manual`: nothing outside it closes it.
-}
closer : Html Msg
closer =
    Header.cornerPopover
        { popover = box.boxId
        , action = "hide"
        , label = "Close the floating track map"
        , glyph = "✕"
        }
