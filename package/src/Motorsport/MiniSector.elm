module Motorsport.MiniSector exposing
    ( MiniSectors, map, names, values, toList
    , get, map2
    )

{-| One value per mini-sector, held as a list of named values in the order a car
drives them.

A mini-sector has no identity beyond its name: the string a drawing writes under
its line and the string two lists are joined on are the same one, spelled by
whichever feed measured the lap. So a circuit with lines of its own supplies them
in a file, and nothing here has to be told their names.

@docs MiniSectors, map, names, values, toList
@docs get, map2

-}


{-| A value per mini-sector, in track order.

The list is the order: unlike [`BySector`](Motorsport-Sector#BySector) there is
no position to read a value off, and a name is looked up rather than indexed.

    names [ { name = "IP1", value = 1 }, { name = "IP2", value = 2 } ]
    --> [ "IP1", "IP2" ]

-}
type alias MiniSectors a =
    List { name : String, value : a }


{-| The names, in track order.
-}
names : MiniSectors a -> List String
names =
    List.map .name


{-| The values, in track order.
-}
values : MiniSectors a -> List a
values =
    List.map .value


{-| The name and value of each mini-sector, in track order.
-}
toList : MiniSectors a -> List ( String, a )
toList =
    List.map (\entry -> ( entry.name, entry.value ))


{-| Change every value, keeping the names and the order.
-}
map : (a -> b) -> MiniSectors a -> MiniSectors b
map f =
    List.map (\entry -> { name = entry.name, value = f entry.value })


{-| The value held for one name.
-}
get : String -> MiniSectors a -> Maybe a
get name entries =
    case entries of
        [] ->
            Nothing

        entry :: rest ->
            if entry.name == name then
                Just entry.value

            else
                get name rest


{-| Combine two sets of per-mini-sector values, mini-sector by mini-sector, read
by name.

The names and the order are the first list's; a name the second has no value for
drops its entry.

    map2 Tuple.pair
        [ { name = "IP1", value = 1 }, { name = "IP2", value = 2 } ]
        [ { name = "IP2", value = "b" }, { name = "IP1", value = "a" } ]
    --> [ { name = "IP1", value = ( 1, "a" ) }, { name = "IP2", value = ( 2, "b" ) } ]

-}
map2 : (a -> b -> c) -> MiniSectors a -> MiniSectors b -> MiniSectors c
map2 f a b =
    List.filterMap
        (\entry ->
            Maybe.map (\value -> { name = entry.name, value = f entry.value value }) (get entry.name b)
        )
        a
