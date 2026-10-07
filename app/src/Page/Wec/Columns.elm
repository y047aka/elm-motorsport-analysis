module Page.Wec.Columns exposing
    ( Model, init, update, Msg(..), StripKey(..), keyName, keysOf, resolve, carsIn
    , Placement(..), placements, carrying, isCarried, placementAttributes, gripId, stripId
    , scrollId, width, gap, pitch, slot, xOf, px
    )

{-| The strip of columns: what order they stand in, which one a pointer is
carrying, and where each is drawn while that goes on.

A column belongs either to a car or to the tracker; `StripKey` is that
choice, and the order -- `Columns` -- is a list of them. Every edit is total.

The names sort into five shelves:

  - `Model`, `init`, `update`, `Msg` -- the strip's state and what moves it.
  - `StripKey`, `keyName` -- who a column is, and the `Html.Keyed` name of one.
  - `keysOf`, `resolve`, `carsIn` -- what order they stand in.
  - `placements`, `carrying`, `isCarried`, `placementAttributes` -- where each
    one is drawn, and whether it is the one under the pointer.
  - `gripId` ... `px` -- the names the page builds DOM out of, and the measures
    the carry arithmetic is done in.

@docs Model, init, update, Msg, StripKey, keyName, keysOf, resolve, carsIn
@docs Placement, placements, carrying, isCarried, placementAttributes, gripId, stripId
@docs scrollId, width, gap, pitch, slot, xOf, px

-}

import Browser.Dom
import Dict exposing (Dict)
import Drag
import Drag.Handle exposing (Pointer)
import Html
import Html.Attributes as Attributes
import List.Extra
import Motorsport.Race.Car exposing (CarNumber)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Task


{-| A column of the strip: a car's, or the tracker's.

The tracker's place in the order means where it stood when the stand-ins
settled: while the stand-ins are live the tracker stands behind them,
whatever their running order becomes.

-}
type StripKey
    = Car CarNumber
    | Tracker


keyName : StripKey -> String
keyName key =
    case key of
        Car carNumber ->
            carNumber

        Tracker ->
            "tracker"


carOfKey : StripKey -> Maybe CarNumber
carOfKey key =
    case key of
        Car carNumber ->
            Just carNumber

        Tracker ->
            Nothing


{-| The order of the strip.

`Live` is the car at the front of each class, re-read from the snapshot as
the race runs, with the tracker's column behind them where its flag says.
`Picked` is fixed, in the order the reader left them in, and any open, close
or move settles the stand-ins into one.

-}
type Columns
    = Live { tracker : Bool }
    | Picked StripKey (List StripKey)


keysOf : Snapshot -> Columns -> List StripKey
keysOf snapshot columns =
    case columns of
        Live { tracker } ->
            List.map (.metadata >> .carNumber >> Car) (leaderOfEachClass snapshot)
                ++ (if tracker then
                        [ Tracker ]

                    else
                        []
                   )

        Picked first rest ->
            first :: rest


{-| The standings mark cars from a snapshot that can be a frame older than
the one being drawn; a car that is gone by then is dropped here, before any
box is drawn for it, so a gap cannot open in the placements.
-}
resolve : Snapshot -> List StripKey -> List StripKey
resolve snapshot =
    List.filter
        (\key ->
            case key of
                Car carNumber ->
                    Snapshot.get carNumber snapshot /= Nothing

                Tracker ->
                    True
        )


carsIn : Snapshot -> List StripKey -> List CarAt
carsIn snapshot keys =
    List.filterMap carOfKey keys
        |> List.filterMap (\carNumber -> Snapshot.get carNumber snapshot)


{-| The classes come in the order their leaders run in.
-}
leaderOfEachClass : Snapshot -> List CarAt
leaderOfEachClass snapshot =
    Snapshot.toClassList snapshot
        |> List.filterMap (Tuple.second >> List.head)


{-| There is no ceiling on how many, and each column draws its own charts on
every frame of playback. A car opened joins the back, and never jumps over
the tracker's column.
-}
open : CarNumber -> Snapshot -> Columns -> Columns
open carNumber snapshot columns =
    let
        current =
            keysOf snapshot columns

        car =
            Car carNumber

        at =
            List.Extra.elemIndex Tracker current
                |> Maybe.withDefault (List.length current)
    in
    if List.member car current then
        columns

    else
        pickedOr columns (List.take at current ++ [ car ] ++ List.drop at current)


close : CarNumber -> Snapshot -> Columns -> Columns
close carNumber snapshot columns =
    keysOf snapshot columns
        |> List.filter ((/=) (Car carNumber))
        |> pickedOr columns


{-| Moving takes a key -- a car's or the tracker's -- and steps it along.
-}
move : StripKey -> Int -> Snapshot -> Columns -> Columns
move key steps snapshot columns =
    let
        current =
            keysOf snapshot columns

        others =
            List.filter ((/=) key) current
    in
    case List.Extra.elemIndex key current of
        Just index ->
            let
                to =
                    clamp 0 (List.length others) (index + steps)
            in
            if to == index then
                columns

            else
                pickedOr columns (List.take to others ++ key :: List.drop to others)

        Nothing ->
            columns


{-| Adding and taking away the tracker's column. Nothing settles: while the
stand-ins are live the tracker follows them as the flag says, and its place
is only fixed by a settle of the cars' own.
-}
showTracker : Snapshot -> Columns -> Columns
showTracker snapshot columns =
    case columns of
        Live _ ->
            Live { tracker = True }

        Picked first rest ->
            if List.member Tracker (first :: rest) then
                columns

            else
                Picked first (rest ++ [ Tracker ])


hideTracker : Snapshot -> Columns -> Columns
hideTracker snapshot columns =
    case columns of
        Live _ ->
            Live { tracker = False }

        Picked first rest ->
            List.filter ((/=) Tracker) (first :: rest)
                |> pickedOr (Live { tracker = False })


{-| The stand-ins are re-read every frame, so a column being carried among
them could change places under the pointer.
-}
settle : Snapshot -> Columns -> Columns
settle snapshot columns =
    pickedOr columns (keysOf snapshot columns)


pickedOr : Columns -> List StripKey -> Columns
pickedOr fallback keys =
    case keys of
        [] ->
            fallback

        first :: rest ->
            Picked first rest


{-| What the reader is told when a column moves.
-}
announcement : StripKey -> List StripKey -> String
announcement key order =
    let
        name =
            case key of
                Car carNumber ->
                    "Car #" ++ carNumber

                Tracker ->
                    "Tracker"
    in
    case List.Extra.elemIndex key order of
        Just index ->
            name ++ " moved to column " ++ String.fromInt (index + 1) ++ " of " ++ String.fromInt (List.length order)

        Nothing ->
            ""


{-| The column under the pointer, and the orders a carry answers to: `before`
stands as it did when the column was picked up, `settled` is what picking it
up made of them. A carry that lands where it began puts `before` back, unless
something else has changed the columns since.
-}
type alias Carry =
    { key : StripKey
    , before : Columns
    , settled : Columns
    }


putBack : Carry -> Columns -> Columns
putBack carry columns =
    if columns == carry.settled then
        carry.before

    else
        columns


{-| How far a carry has gone: the pointer's travel and the strip's together,
since the strip can be scrolled under a pointer that holds still.
-}
withScroll : Model -> Float -> Float
withScroll m distance =
    distance + m.stripScroll.to - m.stripScroll.from


columnsCarried : Float -> Int
columnsCarried distance =
    -- Counted in the canonical `pitch`, not the carried column's own
    -- width: widths decide where a place is drawn, not what a carry turns
    -- over.
    round (distance / pitch)


{-| Where a column is drawn, and whether it is the one being carried.
-}
type Placement
    = Resting
    | Carried Float
    | Shifted Float


{-| While one is carried: that one under the pointer, held to the strip, and
each it has passed a column back the other way.

The carried one is clamped to what actually stands on either side of it;
each displaced one moves by the slot its neighbour vacated.

Nothing moves in the DOM until it is let go of. The grip holds the pointer only
while it stays in the document, and the keyed strip moves a column by taking
it out.

-}
placements : (StripKey -> Float) -> Maybe ( StripKey, Float ) -> List StripKey -> List Placement
placements widthOf underPointer keys =
    let
        slots =
            List.map (widthOf >> slot) keys

        leftEdge index =
            List.take index slots
                |> List.sum

        slotAt index =
            List.Extra.getAt index slots
                |> Maybe.withDefault pitch
    in
    case underPointer |> Maybe.andThen (\( key, distance ) -> List.Extra.elemIndex key keys |> Maybe.map (\from -> ( from, distance ))) of
        Just ( from, distance ) ->
            let
                last =
                    List.length keys - 1

                to =
                    from + clamp -from (last - from) (columnsCarried distance)
            in
            List.indexedMap
                (\index _ ->
                    if index == from then
                        Carried (clamp (negate (leftEdge from)) (List.drop (from + 1) slots |> List.sum) distance)

                    else if from < index && index <= to then
                        Shifted (negate (slotAt (index - 1)))

                    else if to <= index && index < from then
                        Shifted (slotAt index)

                    else
                        Shifted 0
                )
                keys

        Nothing ->
            List.map (always Resting) keys


{-| The column under the pointer and how far it has gone.
-}
carrying : Model -> Maybe ( StripKey, Float )
carrying m =
    Drag.carrying m.carried
        |> Maybe.map (\carry -> ( carry.location.key, withScroll m (Drag.travel carry) ))


isCarried : Placement -> Bool
isCarried placement =
    case placement of
        Carried _ ->
            True

        _ ->
            False


placementAttributes : Placement -> List (Html.Attribute msg)
placementAttributes placement =
    case placement of
        Resting ->
            []

        Carried dx ->
            -- Above the resting columns, which the carry passes: a drag is
            -- drawn over what it goes under.
            [ Attributes.class "relative z-30 rounded-xl bg-background shadow-2xl"
            , Attributes.style "transform" ("translateX(" ++ px dx ++ ")")
            ]

        Shifted dx ->
            [ Attributes.class "transition-transform"
            , Attributes.style "transform" ("translateX(" ++ px dx ++ ")")
            ]


gripId : StripKey -> String
gripId key =
    "column-grip-" ++ keyName key


stripId : String
stripId =
    "column-strip"


{-| The box a car's panel scrolls in. The tracker's column scrolls nothing.
-}
scrollId : CarNumber -> String
scrollId carNumber =
    "column-scroll-" ++ carNumber


{-| The strip's state: the order, the one pointer carrying, how far down each
car's panel was scrolled, and what to say when a column moved.

`stripScroll` is how far the strip had scrolled under the pointer, and what a
carry measures its travel against. It keeps the last carry's reading between
carries; only a carry is ever measured with it.

-}
type alias Model =
    { order : Columns
    , carried : Drag.State Carry
    , stripScroll : { from : Float, to : Float }
    , scrolls : Dict CarNumber Float
    , announcement : String
    }


init : Model
init =
    { order = Live { tracker = False }
    , carried = Drag.init
    , stripScroll = { from = 0, to = 0 }
    , scrolls = Dict.empty
    , announcement = ""
    }


type Msg
    = Open CarNumber
    | Close CarNumber
    | ShowTracker Bool
    | Grab StripKey Pointer
    | Carrying Pointer
    | Release Pointer
    | Cancel Int
    | StripScrolledFrom Float
    | StripScrolled Float
    | Step StripKey Int
    | PanelScrolled CarNumber Float
    | Settled


{-| The field is given per call, not kept: the panels' scroll positions are
put back once the moved column has been drawn in its new place -- the grip's
focus first, since focusing scrolls the grip into view and that scrolls the
panel too.

A frame with no round leaves the order where it was; the pointer is still
answered to, and settles nothing that cannot be settled.

-}
update : Maybe Snapshot -> Msg -> Model -> ( Model, Cmd Msg )
update field msg m =
    case msg of
        Open carNumber ->
            edit field m (open carNumber)

        Close carNumber ->
            edit field m (close carNumber)
                |> Tuple.mapFirst (\after -> { after | scrolls = Dict.remove carNumber m.scrolls })

        ShowTracker shown ->
            shownColumn field shown m

        Grab key pointer ->
            grab field key pointer m

        Carrying pointer ->
            let
                ( carried, _ ) =
                    Drag.update (Drag.Move pointer) m.carried
            in
            ( { m | carried = carried }, Cmd.none )

        Release pointer ->
            release field pointer m

        Cancel pointerId ->
            case Drag.update (Drag.Cancel pointerId) m.carried of
                ( carried, Just done ) ->
                    letGo { m | carried = carried } done.location

                ( carried, Nothing ) ->
                    ( { m | carried = carried }, Cmd.none )

        StripScrolledFrom left ->
            ( { m | stripScroll = { from = left, to = left } }, Cmd.none )

        StripScrolled left ->
            ( { m | stripScroll = { from = m.stripScroll.from, to = left } }, Cmd.none )

        Step key steps ->
            stepBy field key steps m

        PanelScrolled carNumber top ->
            ( { m | scrolls = Dict.insert carNumber top m.scrolls }, Cmd.none )

        Settled ->
            ( m, Cmd.none )


shownColumn : Maybe Snapshot -> Bool -> Model -> ( Model, Cmd Msg )
shownColumn field shown m =
    case field of
        Just round ->
            ( { m
                | order =
                    if shown then
                        showTracker round m.order

                    else
                        hideTracker round m.order
              }
            , Cmd.none
            )

        Nothing ->
            ( m, Cmd.none )


grab : Maybe Snapshot -> StripKey -> Pointer -> Model -> ( Model, Cmd Msg )
grab field key pointer m =
    if Drag.isCarrying m.carried then
        ( m, Cmd.none )

    else
        let
            settled =
                case field of
                    Just round ->
                        settle round m.order

                    Nothing ->
                        m.order

            ( carried, _ ) =
                Drag.update (Drag.Pick { key = key, before = m.order, settled = settled } pointer) m.carried
        in
        ( { m | order = settled, carried = carried, stripScroll = { from = 0, to = 0 } }
        , Browser.Dom.getViewportOf stripId
            |> Task.attempt (Result.map (.viewport >> .x >> StripScrolledFrom) >> Result.withDefault Settled)
        )


release : Maybe Snapshot -> Pointer -> Model -> ( Model, Cmd Msg )
release field pointer m =
    case Drag.update (Drag.Drop pointer) m.carried of
        ( carried, Just done ) ->
            let
                after =
                    { m | carried = carried }
            in
            case field of
                Just round ->
                    let
                        moved =
                            move done.location.key (columnsCarried (withScroll after done.travel)) round m.order
                    in
                    if moved == m.order then
                        letGo after done.location

                    else
                        reorder round { moved = done.location.key, refocus = False } after moved

                Nothing ->
                    letGo after done.location

        ( carried, Nothing ) ->
            ( { m | carried = carried }, Cmd.none )


stepBy : Maybe Snapshot -> StripKey -> Int -> Model -> ( Model, Cmd Msg )
stepBy field key steps m =
    if Drag.isCarrying m.carried then
        -- A step would move the strip under the carried column, and
        -- could take the grip holding the pointer out of the document.
        ( m, Cmd.none )

    else
        case field of
            Just round ->
                let
                    moved =
                        move key steps round m.order
                in
                if moved == m.order then
                    ( m, Cmd.none )

                else
                    reorder round { moved = key, refocus = True } m moved

            Nothing ->
                ( m, Cmd.none )


letGo : Model -> Carry -> ( Model, Cmd Msg )
letGo m carry =
    ( { m | order = putBack carry m.order }, Cmd.none )


edit : Maybe Snapshot -> Model -> (Snapshot -> Columns -> Columns) -> ( Model, Cmd Msg )
edit field m f =
    case field of
        Just round ->
            ( { m | order = f round m.order }, Cmd.none )

        Nothing ->
            ( m, Cmd.none )


{-| The keyed strip moves a column by taking it out of the document, which
loses how far down it was scrolled and the focus of anything in it. Both are
put back once it has been drawn in its new place, the focus first: focusing
scrolls the grip, at the top of its column, into view.
-}
reorder : Snapshot -> { moved : StripKey, refocus : Bool } -> Model -> Columns -> ( Model, Cmd Msg )
reorder round { moved, refocus } m order =
    let
        focus : Task.Task Never ()
        focus =
            if refocus then
                Browser.Dom.focus (gripId moved) |> Task.onError (\_ -> Task.succeed ())

            else
                Task.succeed ()
    in
    ( { m | order = order, announcement = announcement moved (keysOf round order) }
    , focus
        |> Task.andThen (\_ -> restoreScrolls m.scrolls)
        |> Task.perform (\_ -> Settled)
    )


restoreScrolls : Dict CarNumber Float -> Task.Task Never ()
restoreScrolls scrolls =
    Dict.toList scrolls
        |> List.map
            (\( carNumber, top ) ->
                Browser.Dom.setViewportOf (scrollId carNumber) 0 top
                    |> Task.onError (\_ -> Task.succeed ())
            )
        |> Task.sequence
        |> Task.map (\_ -> ())


{-| A column is a fixed width, not a share of the strip, and the strip
scrolls sideways rather than resizing its columns. The width is what the
panel's own content wants; a change to it is a change to `pitch`, and so to
every carry distance.

318 is the panel's floor: the widest thing in it is the comparison's tab row,
which wants 286px -- the three chart labels and the three stretch labels, one
`shrink-0` button apiece. 318 is that row plus the card's padding, where the
row stops scrolling within itself.

-}
width : Float
width =
    318


gap : Float
gap =
    10


{-| From one column's left edge to the next one's when that column is
`wide`: its own width, and the gap it is followed by. `pitch` is this at
`width`.
-}
slot : Float -> Float
slot wide =
    wide + gap


{-| Where the column at this index of this strip begins, measured from the
strip's own left edge: the slots of every column before it.
-}
xOf : (StripKey -> Float) -> List StripKey -> Int -> Float
xOf widthOf keys index =
    keys
        |> List.take index
        |> List.map (widthOf >> slot)
        |> List.sum


pitch : Float
pitch =
    width + gap


px : Float -> String
px n =
    String.fromFloat n ++ "px"
