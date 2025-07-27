module SortedListTest exposing (suite)

import Expect
import SortedList exposing (SortedList)
import Motorsport.Ordering exposing (ByPosition)
import Motorsport.Utils exposing (compareBy)
import Test exposing (Test, describe, test)


type alias TestItem =
    { position : Int
    , name : String
    }


suite : Test
suite =
    describe "SortedList"
        [ describe "sortBy"
            [ test "creates sorted collection by position" <|
                \_ ->
                    let
                        items =
                            [ { position = 3, name = "Third" }
                            , { position = 1, name = "First" }
                            , { position = 2, name = "Second" }
                            ]

                        sorted =
                            SortedList.sortBy (compareBy .position) items

                        result =
                            SortedList.toList sorted
                    in
                    result
                        |> List.map .position
                        |> Expect.equal [ 1, 2, 3 ]
            , test "maintains sorting guarantee after creation" <|
                \_ ->
                    let
                        items =
                            [ { position = 5, name = "Fifth" }
                            , { position = 1, name = "First" }
                            , { position = 3, name = "Third" }
                            ]

                        sorted =
                            SortedList.sortBy (compareBy .position) items

                        result =
                            SortedList.toList sorted
                    in
                    result
                        |> List.map .name
                        |> Expect.equal [ "First", "Third", "Fifth" ]
            ]
        , describe "toList"
            [ test "extracts list from sorted collection" <|
                \_ ->
                    let
                        items =
                            [ { position = 1, name = "Only" } ]

                        sorted =
                            SortedList.sortBy (compareBy .position) items

                        result =
                            SortedList.toList sorted
                    in
                    result
                        |> Expect.equal items
            ]
        , describe "map"
            [ test "preserves sorting while transforming" <|
                \_ ->
                    let
                        items =
                            [ { position = 2, name = "Second" }
                            , { position = 1, name = "First" }
                            ]

                        sorted =
                            SortedList.sortBy (compareBy .position) items

                        mapped =
                            SortedList.map .name sorted

                        result =
                            SortedList.toList mapped
                    in
                    result
                        |> Expect.equal [ "First", "Second" ]
            ]
        , describe "type safety"
            [ test "phantom type prevents mixing different sorting types" <|
                \_ ->
                    -- This test ensures that different sorting phantom types
                    -- cannot be mixed at compile time. The test itself just
                    -- verifies that the type system works correctly.
                    let
                        byPosition : SortedList ByPosition TestItem
                        byPosition =
                            SortedList.sortBy (compareBy .position)
                                [ { position = 1, name = "Test" } ]
                    in
                    SortedList.toList byPosition
                        |> List.length
                        |> Expect.equal 1
            ]
        ]