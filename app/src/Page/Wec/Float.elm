module Page.Wec.Float exposing (Model, Msg(..), init, update, view, trigger)

{-| The track map floated over the columns: hidden until the tracker column's `◱`
asks for it, sized by a grip along each of its four edges and at each of its four corners, carried by a fifth, and taking part in none of the strip's grid.

The box is a `popover`, and a `manual` one: the browser keeps whether it is open, the two presses only name it, and nothing here can be closed by a press outside it -- the columns are worked while the map is up.

The camera belongs here: this is the one drawing raised off the ground it was surveyed on.

@docs Model, Msg, init, update, view, trigger

-}

import Browser.Dom
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
import Task
import View.CarDetail.Header as Header
import View.TrackMap3d as TrackMap3d


type alias Model =
    { shown : Bool
    , width : Resize.Model
    , height : Resize.Model
    , shift : Shift.Model
    , camera : Track3d.Model
    , window : { width : Float, height : Float }
    }


init : Model
init =
    { shown = False
    , width = Resize.init defaultWidth
    , height = Resize.init defaultHeight
    , shift = Shift.init
    , camera = Track3d.init
    , window = unmeasured
    }


{-| No window has been read yet. Nothing grows against it: a grip lies on a popover the
UA keeps hidden until the column asks, and the open reads the window before any grip can
be pressed.
-}
unmeasured : { width : Float, height : Float }
unmeasured =
    { width = 4000, height = 4000 }


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
    | Window { width : Float, height : Float }
    | ShiftMsg Shift.Msg
    | CameraMsg Track3d.Msg


{-| The box the floating map opens at.
480 by 180 is `Tracker3d.box`'s own three to one once the card's padding is gone.
The map is stood at the bottom right of the page, and every one of its four edges is a grip: the two away from the corner it is stood at grow `AgainstPointer`, and the two at it are `WithPointer` and take the box along with the size, so the edge opposite the one held stays where it was.
-}
defaultWidth : Float
defaultWidth =
    480


defaultHeight : Float
defaultHeight =
    180


{-| How small each size may go, and nothing more: how far it may go is the window's, and
`grow` reads it there.
-}
widthFence : Resize.Fence
widthFence =
    { min = 280
    , max = Nothing
    }


heightFence : Resize.Fence
heightFence =
    { min = 120
    , max = Nothing
    }


{-| The room between the corner the box is stood at and the window's: the box's own
`bottom-2.5 right-2.5`, since a popover in the top layer is inset from the _viewport_
and not from `mainGrid` -- the same reason `inset: 0` is answered with `top-auto
left-auto`.
-}
cornerRoom : Float
cornerRoom =
    10


{-| An edge the box keeps a size by: the words its grip is called by, where that grip
stands, and the size it moves.

The box is pinned at its bottom right, so the two edges there are `WithPointer` and take
the box along with the size, and the other two are `AgainstPointer` and grow away from a
box that stays where it stands. Which end the grip bounds is therefore one fact and not
two: the grip at the pinned end is the one that carries the box.

-}
type alias Side =
    { name : String
    , at : String
    , edge : Resize.Edge
    }


left : Side
left =
    { name = "left"
    , at = "-left-2.5"
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
    { name = "right"
    , at = "-right-2.5"
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
    { name = "top"
    , at = "-top-2.5"
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
    { name = "bottom"
    , at = "-bottom-2.5"
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

Its id, its words and where its grip stands are all the two edges it is the meeting of.

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
    let
        ( width, height ) =
            case direction of
                Handle.NorthWest ->
                    ( left, top )

                Handle.NorthEast ->
                    ( right, top )

                Handle.SouthWest ->
                    ( left, bottom )

                Handle.SouthEast ->
                    ( right, bottom )

        names =
            height.name ++ "-" ++ width.name
    in
    { id = "tracker-float-" ++ names ++ "-grip"
    , label = "Resize the floating track map from its " ++ names ++ " corner"
    , at = height.at ++ " " ++ width.at
    , width = width
    , height = height
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
            ( { m | shown = shown }
            , if shown then
                measure

              else
                Cmd.none
            )

        Window window ->
            ( { m | window = window }, Cmd.none )

        LeftMsg sub ->
            let
                grown =
                    grow left.edge.id (alongX left m) sub
            in
            ( { m | width = grown.size }, measureOn sub )

        RightMsg sub ->
            let
                grown =
                    grow right.edge.id (alongX right m) sub

                shift =
                    m.shift
            in
            ( { m | width = grown.size, shift = { shift | x = grown.shift } }, measureOn sub )

        TopMsg sub ->
            let
                grown =
                    grow top.edge.id (alongY top m) sub
            in
            ( { m | height = grown.size }, measureOn sub )

        BottomMsg sub ->
            let
                grown =
                    grow bottom.edge.id (alongY bottom m) sub

                shift =
                    m.shift
            in
            ( { m | height = grown.size, shift = { shift | y = grown.shift } }, measureOn sub )

        GrabCorner direction place ->
            ( growCorner direction Resize.Grab place m, measure )

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


{-| One axis of a drag: the side being grown, the size it holds, how far the box has gone
along that axis, and how far the window goes along it.
-}
type alias Drag =
    { side : Side
    , size : Resize.Model
    , shift : Float
    , window : Float
    }


alongX : Side -> Model -> Drag
alongX side m =
    { side = side, size = m.width, shift = m.shift.x, window = m.window.width }


alongY : Side -> Model -> Drag
alongY side m =
    { side = side, size = m.height, shift = m.shift.y, window = m.window.height }


{-| Whether the box is carried along by the growth. The box is pinned at one end of each
axis and a grip there moves the box by its own travel, while a grip at the other end
leaves it stood -- which is what `Grows` already says, so the two cannot disagree.
-}
carried : Side -> Bool
carried side =
    side.edge.grows == Resize.WithPointer


{-| How far the edge held can travel before it lands on the window's own edge: the window
on the far side, zero on the near one. The box stands at `bottom-2.5 right-2.5` and is
then carried by `shift`, so its far end sits at `window - cornerRoom + shift`.
-}
room : Drag -> Float
room d =
    case d.side.edge.grows of
        Resize.WithPointer ->
            cornerRoom - d.shift

        Resize.AgainstPointer ->
            d.window - cornerRoom + d.shift - d.size.size


{-| One axis of a drag on a size, by the grip named `gripId`: the edge held travels to the
window's own edge and no further, and the box goes along only when the grip is at the end
the box is pinned at. Either way the ceiling is the same at every move of one drag,
because size and shift both grow by the travel.
-}
grow : String -> Drag -> Resize.Msg -> { size : Resize.Model, shift : Float }
grow gripId d msg =
    let
        base =
            d.side.edge

        ceiling =
            d.size.size + room d

        edge =
            { base
                | id = gripId
                , fence =
                    { min = base.fence.min
                    , max =
                        case base.fence.max of
                            Just cap ->
                                Just (min cap ceiling)

                            Nothing ->
                                Just ceiling
                    }
            }

        size =
            Resize.update edge msg d.size
    in
    { size = size
    , shift =
        if carried d.side then
            d.shift + size.size - d.size.size

        else
            d.shift
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
            grow c.id (alongX c.width m) (toMsg { id = place.id, along = place.x })

        height =
            grow c.id (alongY c.height m) (toMsg { id = place.id, along = place.y })

        shift =
            m.shift
    in
    { m | width = width.size, height = height.size, shift = { shift | x = width.shift, y = height.shift } }


{-| How far the window goes, read from the browser. The ceiling a drag stops at is the
window's and the window can have been resized since the last reading, so the window is
read again when a grip takes a size up -- the way a carry measures the box it is about to
move.
-}
measure : Cmd Msg
measure =
    Browser.Dom.getViewport
        |> Task.map (\{ viewport } -> Window { width = viewport.width, height = viewport.height })
        |> Task.onError (\_ -> Task.succeed (Window unmeasured))
        |> Task.perform identity


measureOn : Resize.Msg -> Cmd Msg
measureOn msg =
    case msg of
        Resize.Grab _ ->
            measure

        _ ->
            Cmd.none


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
        , div [ Attributes.class ("absolute " ++ left.at ++ " top-0 z-10 grid h-full w-2.5 place-items-center") ]
            [ Html.map LeftMsg (Resize.grip left.edge m.width) ]
        , div [ Attributes.class ("absolute " ++ right.at ++ " top-0 z-10 grid h-full w-2.5 place-items-center") ]
            [ Html.map RightMsg (Resize.grip right.edge m.width) ]
        , div [ Attributes.class ("absolute " ++ top.at ++ " left-0 z-10 grid h-2.5 w-full content-center") ]
            [ Html.map TopMsg (Resize.grip top.edge m.height) ]
        , div [ Attributes.class ("absolute " ++ bottom.at ++ " left-0 z-10 grid h-2.5 w-full content-center") ]
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


{-| The card takes 16px of padding off each side of the box, and the box keeps a 1px
border, before the drawing has anything to say about its own size.
-}
cardLoss : Float
cardLoss =
    34


surface : Model -> Track -> Snapshot -> Html Msg
surface m track snapshot =
    TrackMap3d.surface
        { model = m.camera
        , toMsg = CameraMsg
        , track = track
        , snapshot = snapshot
        , size =
            { width = m.width.size - cardLoss
            , height = m.height.size - cardLoss
            }
        }


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
