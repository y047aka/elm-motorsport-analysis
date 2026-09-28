module Page.Wec.Columns exposing
    ( Columns(..), StripKey(..), keyName, carOfKey
    , keysOf, resolve, carsIn
    , open, close, move, settle, showTracker, hideTracker
    , Carry, heldBy, putBack, columnsCarried
    , Placement(..), placements, isCarried, placementAttributes
    , announcement
    , gripId, width, gap, px
    )

{-| The strip of columns: what order they stand in, which one a pointer is
carrying, and where each is drawn while that goes on.

A column belongs either to a car or to the tracker; `StripKey` is that
choice, and the order -- `Columns` -- is a list of them. The page keeps one
of these and its one `Carry`, and every edit here is total: nothing fails,
and stand-ins that have settled stay settled.

-}

import Html
import Html.Attributes as Attributes
import List.Extra
import Motorsport.Race.Car exposing (CarNumber)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)


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


{-| `ClassLeaders` is the car at the front of each class, re-read from the
snapshot as the race runs. `Picked` is fixed, in the order the reader left
them in, and any open, close or move settles the stand-ins into one -- the
tracker's column, once asked for, holds its place among the cars in that
order too.
-}
type Columns
    = ClassLeaders
    | Picked StripKey (List StripKey)


{-| The order the strip stands in: the cars' own, and the tracker behind the
stand-ins until a settle fixes it among them.
-}
keysOf : Bool -> Snapshot -> Columns -> List StripKey
keysOf tracker snapshot columns =
    case columns of
        ClassLeaders ->
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
every frame of playback. Opening and closing name the car, and join the cars
at the back of them -- before the tracker when its column stands among them.
-}
open : Bool -> CarNumber -> Snapshot -> Columns -> Columns
open tracker carNumber snapshot columns =
    let
        current =
            keysOf tracker snapshot columns

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


close : Bool -> CarNumber -> Snapshot -> Columns -> Columns
close tracker carNumber snapshot columns =
    keysOf tracker snapshot columns
        |> List.filter ((/=) (Car carNumber))
        |> pickedOr columns


{-| Moving takes a key -- a car's or the tracker's -- and steps it along.
-}
move : Bool -> StripKey -> Int -> Snapshot -> Columns -> Columns
move tracker key steps snapshot columns =
    let
        current =
            keysOf tracker snapshot columns

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
        ClassLeaders ->
            columns

        Picked first rest ->
            if List.member Tracker (first :: rest) then
                columns

            else
                Picked first (rest ++ [ Tracker ])


hideTracker : Snapshot -> Columns -> Columns
hideTracker snapshot columns =
    case columns of
        ClassLeaders ->
            columns

        Picked first rest ->
            List.filter ((/=) Tracker) (first :: rest)
                |> pickedOr ClassLeaders


{-| The stand-ins are re-read every frame, so a column being carried among
them could change places under the pointer.
-}
settle : Bool -> Snapshot -> Columns -> Columns
settle tracker snapshot columns =
    pickedOr columns (keysOf tracker snapshot columns)


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


{-| A column being carried along the strip by one pointer. How far it has gone
is the pointer's travel and the strip's together, since the strip can be
scrolled under a pointer that holds still.

`before` is the columns as they stood when it was picked up, and `settled` what
picking it up made of them. A carry that lands where it began puts `before`
back, unless something else has changed the columns since.

-}
type alias Carry =
    { key : StripKey
    , pointerId : Int
    , before : Columns
    , settled : Columns
    , from : Float
    , at : Float
    , scrolledFrom : Float
    , scrolledTo : Float
    }


heldBy : Int -> Maybe Carry -> Maybe Carry
heldBy pointerId =
    Maybe.andThen
        (\carry ->
            if carry.pointerId == pointerId then
                Just carry

            else
                Nothing
        )


putBack : Carry -> Columns -> Columns
putBack carry columns =
    if columns == carry.settled then
        carry.before

    else
        columns


travel : Carry -> Float
travel carry =
    carry.at - carry.from + carry.scrolledTo - carry.scrolledFrom


columnsCarried : Carry -> Int
columnsCarried carry =
    round (travel carry / pitch)


{-| Where a column is drawn, and whether it is the one being carried.
-}
type Placement
    = Resting
    | Carried Float
    | Shifted Float


{-| While one is carried: that one under the pointer, held to the strip, and
each it has passed a column back the other way.

Nothing moves in the DOM until it is let go of. The grip holds the pointer only
while it stays in the document, and the keyed strip moves a column by taking
it out.

-}
placements : Maybe Carry -> List StripKey -> List Placement
placements carried keys =
    case carried |> Maybe.andThen (\carry -> List.Extra.elemIndex carry.key keys |> Maybe.map (Tuple.pair carry)) of
        Just ( carry, from ) ->
            let
                last =
                    List.length keys - 1

                to =
                    from + clamp -from (last - from) (columnsCarried carry)
            in
            List.indexedMap
                (\index _ ->
                    if index == from then
                        Carried (clamp (toFloat -from * pitch) (toFloat (last - from) * pitch) (travel carry))

                    else if from < index && index <= to then
                        Shifted -pitch

                    else if to <= index && index < from then
                        Shifted pitch

                    else
                        Shifted 0
                )
                keys

        Nothing ->
            List.map (always Resting) keys


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
            [ Attributes.class "relative z-10 rounded-xl bg-background shadow-2xl"
            , Attributes.style "transform" ("translateX(" ++ px dx ++ ")")
            ]

        Shifted dx ->
            [ Attributes.class "transition-transform"
            , Attributes.style "transform" ("translateX(" ++ px dx ++ ")")
            ]


gripId : StripKey -> String
gripId key =
    "column-grip-" ++ keyName key


{-| A column is 360px, not a share of the cell. The widest thing in the panel is
the comparison's tab row, which wants 302px of the 328 a column of this width
hands it. The floor is 335, so the 26px over is what is left for a font that is
not the one this was measured in.
-}
width : Float
width =
    360


gap : Float
gap =
    10


pitch : Float
pitch =
    width + gap


px : Float -> String
px n =
    String.fromFloat n ++ "px"
