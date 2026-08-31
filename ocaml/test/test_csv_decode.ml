open Motorsport_cli
open Harness
module Decode = Util_csv_decode

(* ------------------------------------------------------------------------- *)
(* Helpers                                                                    *)
(* ------------------------------------------------------------------------- *)

(** The [Hex.fromString] of elm-community/elm-hex, ported. Used by the
    [from_result] tests alone. *)
let hex_from_string input =
  let hex_digit c =
    match c with
    | '0' .. '9' -> Ok (Char.code c - Char.code '0')
    | 'a' .. 'f' -> Ok (Char.code c - Char.code 'a' + 10)
    | 'A' .. 'F' -> Ok (Char.code c - Char.code 'A' + 10)
    | bad -> Error bad
  in
  if input = "" then Error "Empty strings are not valid hexadecimal strings."
  else
    String.fold_left
      (fun acc c ->
        match acc with
        | Ok n -> (
          match hex_digit c with
          | Ok d -> Ok ((n * 16) + d)
          | Error bad ->
            Error
              (Printf.sprintf "\"%s\" is not a valid hexadecimal string because %c is not a valid hexadecimal character."
                 input bad))
        | Error e -> Error e)
      (Ok 0) input

(** Elm's [round : Float -> Int], which goes half-up where OCaml's [Float.round]
    goes half away from zero. *)
let round f = int_of_float (Float.floor (f +. 0.5))

let show_list show xs = "[" ^ String.concat "; " (List.map show xs) ^ "]"

let show_result show = function
  | Ok xs -> "Ok " ^ show_list show xs
  | Error e -> "Error(" ^ Decode.error_to_string e ^ ")"

let show_message_result show = function
  | Ok xs -> "Ok " ^ show_list show xs
  | Error message -> "Error(" ^ message ^ ")"

let quoted s = "\"" ^ s ^ "\""
let show_unit () = "()"

let suite =
  ( "Util.Csv.TestDecode",
    [
      (* --------------------------------------------------------------- *)
      (* string                                                          *)
      (* --------------------------------------------------------------- *)
      ( "testString_aBlankString",
        fun () ->
          assert_eq ~show:(show_result quoted) ~expected:(Ok [ "" ])
            (Decode.decode_csv Decode.No_field_names (Decode.string ()) "\"\"") );
      ( "testString_aUnquotedValue",
        fun () ->
          assert_eq ~show:(show_result quoted) ~expected:(Ok [ "a" ])
            (Decode.decode_csv Decode.No_field_names (Decode.string ()) "a") );
      ( "testString_anInteger",
        fun () ->
          assert_eq ~show:(show_result quoted) ~expected:(Ok [ "1" ])
            (Decode.decode_csv Decode.No_field_names (Decode.string ()) "1") );
      ( "testString_multipleColumns",
        fun () ->
          assert_eq ~show:(show_result quoted)
            ~expected:
              (Error (Decode.Decoding_errors [ Decode.Field_decoding_error (0, Decode.Only_column, Decode.Expected_one_column 2) ]))
            (Decode.decode_csv Decode.No_field_names (Decode.string ()) "1,2") );
      (* --------------------------------------------------------------- *)
      (* int                                                             *)
      (* --------------------------------------------------------------- *)
      ( "testInt_aValidInteger",
        fun () ->
          assert_eq ~show:(show_result string_of_int) ~expected:(Ok [ 1 ])
            (Decode.decode_csv Decode.No_field_names (Decode.int ()) "1") );
      ( "testInt_anIntegerWithSpacesAround",
        fun () ->
          assert_eq ~show:(show_result string_of_int) ~expected:(Ok [ 1 ])
            (Decode.decode_csv Decode.No_field_names (Decode.int ()) " 1 ") );
      ( "testInt_anInvalidInteger",
        fun () ->
          assert_eq ~show:(show_result string_of_int)
            ~expected:
              (Error (Decode.Decoding_errors [ Decode.Field_decoding_error (0, Decode.Only_column, Decode.Expected_int "a") ]))
            (Decode.decode_csv Decode.No_field_names (Decode.int ()) "a") );
      ( "testInt_multipleColumns",
        fun () ->
          assert_eq ~show:(show_result string_of_int)
            ~expected:
              (Error (Decode.Decoding_errors [ Decode.Field_decoding_error (0, Decode.Only_column, Decode.Expected_one_column 2) ]))
            (Decode.decode_csv Decode.No_field_names (Decode.int ()) "1,2") );
      (* --------------------------------------------------------------- *)
      (* float                                                           *)
      (* --------------------------------------------------------------- *)
      ( "testFloat_aFloatShapedLikeAnInteger",
        fun () ->
          assert_eq ~show:(show_result string_of_float) ~expected:(Ok [ 1.0 ])
            (Decode.decode_csv Decode.No_field_names (Decode.float ()) "1") );
      ( "testFloat_aFloatShapedLikeAFloatingPointNumber",
        fun () ->
          assert_eq ~show:(show_result string_of_float) ~expected:(Ok [ 3.14 ])
            (Decode.decode_csv Decode.No_field_names (Decode.float ()) "3.14") );
      ( "testFloat_aFloatWithSpacesAround",
        fun () ->
          assert_eq ~show:(show_result string_of_float) ~expected:(Ok [ 3.14 ])
            (Decode.decode_csv Decode.No_field_names (Decode.float ()) " 3.14 ") );
      ( "testFloat_anInvalidFloat",
        fun () ->
          assert_eq ~show:(show_result string_of_float)
            ~expected:
              (Error (Decode.Decoding_errors [ Decode.Field_decoding_error (0, Decode.Only_column, Decode.Expected_float "a") ]))
            (Decode.decode_csv Decode.No_field_names (Decode.float ()) "a") );
      ( "testFloat_multipleColumns",
        fun () ->
          assert_eq ~show:(show_result string_of_float)
            ~expected:
              (Error (Decode.Decoding_errors [ Decode.Field_decoding_error (0, Decode.Only_column, Decode.Expected_one_column 2) ]))
            (Decode.decode_csv Decode.No_field_names (Decode.float ()) "1,2") );
      (* --------------------------------------------------------------- *)
      (* blank                                                           *)
      (* --------------------------------------------------------------- *)
      ( "testBlank_whenTheFieldIsBlank",
        fun () ->
          assert_true (Decode.decode_csv Decode.No_field_names (Decode.blank (Decode.int ())) "" = Ok []) );
      ( "testBlank_whenTheFieldContainsSpaces",
        fun () ->
          assert_true (Decode.decode_csv Decode.No_field_names (Decode.blank (Decode.int ())) "  " = Ok [ None ]) );
      ( "testBlank_whenTheFieldContainsWhitespaceCharacters",
        fun () ->
          assert_true
            (Decode.decode_csv Decode.No_field_names (Decode.blank (Decode.int ())) "\" \t\n\"" = Ok [ None ]) );
      ( "testBlank_whenTheFieldIsNonBlankButNotValid",
        fun () ->
          assert_true
            (Decode.decode_csv Decode.No_field_names (Decode.blank (Decode.int ())) "banana"
            = Error (Decode.Decoding_errors [ Decode.Field_decoding_error (0, Decode.Only_column, Decode.Expected_int "banana") ]))
      );
      ( "testBlank_whenTheFieldIsNonBlankAndValid",
        fun () ->
          assert_true (Decode.decode_csv Decode.No_field_names (Decode.blank (Decode.int ())) "1" = Ok [ Some 1 ]) );
      (* --------------------------------------------------------------- *)
      (* column                                                          *)
      (* --------------------------------------------------------------- *)
      ( "testColumn_canGetTheOnlyColumn",
        fun () ->
          assert_eq ~show:(show_result quoted) ~expected:(Ok [ "a" ])
            (Decode.decode_csv Decode.No_field_names (Decode.column 0 (Decode.string ())) "a") );
      ( "testColumn_canGetAnArbitraryColumn",
        fun () ->
          assert_eq ~show:(show_result quoted) ~expected:(Ok [ "b" ])
            (Decode.decode_csv Decode.No_field_names (Decode.column 1 (Decode.string ())) "a,b,c") );
      ( "testColumn_issuesAnErrorIfTheColumnDoesntExist",
        fun () ->
          assert_eq ~show:(show_result quoted)
            ~expected:
              (Error
                 (Decode.Decoding_errors
                    [ Decode.Field_decoding_error (0, Decode.Column 1, Decode.Column_not_found 1) ]))
            (Decode.decode_csv Decode.No_field_names (Decode.column 1 (Decode.string ())) "a") );
      (* --------------------------------------------------------------- *)
      (* field                                                           *)
      (* --------------------------------------------------------------- *)
      ( "testField_failsWhenNoFieldNamesAreProvidedOrPresent",
        fun () ->
          assert_eq ~show:(show_result quoted)
            ~expected:(Error (Decode.Decoding_errors [ Decode.Field_not_provided "Name" ]))
            (Decode.decode_csv Decode.No_field_names (Decode.field "Name" (Decode.string ())) "a") );
      ( "testField_failsWhenTheProvidedHeadersDontContainTheName",
        fun () ->
          assert_eq ~show:(show_result quoted)
            ~expected:(Error (Decode.Decoding_errors [ Decode.Field_not_provided "Name" ]))
            (Decode.decode_csv (Decode.Custom_field_names []) (Decode.field "Name" (Decode.string ())) "a") );
      ( "testField_failsWhenTheFirstRowDoesntContainTheName",
        fun () ->
          assert_eq ~show:(show_result quoted)
            ~expected:(Error (Decode.Decoding_errors [ Decode.Field_not_provided "Name" ]))
            (Decode.decode_csv Decode.Field_names_from_first_row (Decode.field "Name" (Decode.string ())) "Blah\r\na")
      );
      ( "testField_failsWhenThereIsNoFirstRow",
        fun () ->
          assert_eq ~show:(show_result quoted) ~expected:(Error Decode.No_field_names_on_first_row)
            (Decode.decode_csv Decode.Field_names_from_first_row (Decode.field "Name" (Decode.string ())) "") );
      ( "testField_failsWhenNameIsNotPresentInTheFirstRow",
        fun () ->
          assert_eq ~show:(show_result quoted)
            ~expected:(Error (Decode.Decoding_errors [ Decode.Field_not_provided "Name" ]))
            (Decode.decode_csv Decode.Field_names_from_first_row (Decode.field "Name" (Decode.string ())) "Bad\r\nAtlas")
      );
      ( "testField_failsWhenTheAssociatedColumnIsNotPresentInTheRow",
        fun () ->
          assert_eq ~show:(show_result quoted)
            ~expected:
              (Error
                 (Decode.Decoding_errors
                    [ Decode.Field_decoding_error (1, Decode.Field ("Other", Some 1), Decode.Field_not_found "Other") ]))
            (Decode.decode_csv Decode.Field_names_from_first_row
               (Decode.field "Other" (Decode.string ()))
               "Name,Other\r\nAtlas") );
      ( "testField_retrievesTheFieldFromCustomProvidedFields",
        fun () ->
          assert_eq ~show:(show_result quoted) ~expected:(Ok [ "a" ])
            (Decode.decode_csv (Decode.Custom_field_names [ "Name" ]) (Decode.field "Name" (Decode.string ())) "a") );
      ( "testField_usesTheHeadersOnTheFirstRowIfPresent",
        fun () ->
          assert_eq ~show:(show_result quoted) ~expected:(Ok [ "Atlas" ])
            (Decode.decode_csv Decode.Field_names_from_first_row (Decode.field "Name" (Decode.string ())) "Name\r\nAtlas")
      );
      ( "testField_usesTheHeadersOnTheFirstRowTrimmed",
        fun () ->
          assert_eq ~show:(show_result quoted) ~expected:(Ok [ "Atlas" ])
            (Decode.decode_csv Decode.Field_names_from_first_row
               (Decode.field "Name" (Decode.string ()))
               " Name \r\nAtlas") );
      ( "testField_failsWithTheRightLineNumberAfterGettingFieldNamesFromTheFirstRow",
        fun () ->
          assert_eq ~show:(show_result string_of_int)
            ~expected:
              (Error
                 (Decode.Decoding_errors
                    [
                      Decode.Field_decoding_error
                        (1, Decode.Field ("Number", Some 0), Decode.Expected_int "not a number");
                    ]))
            (Decode.decode_csv Decode.Field_names_from_first_row
               (Decode.field "Number" (Decode.int ()))
               "Number\r\nnot a number") );
      (* --------------------------------------------------------------- *)
      (* map functions                                                   *)
      (* --------------------------------------------------------------- *)
      ( "testMap_canMapASingleValue",
        fun () ->
          assert_eq ~show:(show_result string_of_int) ~expected:(Ok [ 10 ])
            (Decode.decode_csv Decode.No_field_names
               (Decode.column 0 (Decode.int ()) |> Decode.map (fun i -> i * 2))
               "5") );
      ( "testMap_map2",
        fun () ->
          assert_true
            (Decode.decode_csv Decode.No_field_names
               (Decode.map2 (fun a b -> (a, b)) (Decode.column 0 (Decode.int ())) (Decode.column 1 (Decode.string ())))
               "1,Atlas"
            = Ok [ (1, "Atlas") ]) );
      ( "testMap_map3",
        fun () ->
          assert_true
            (Decode.decode_csv Decode.No_field_names
               (Decode.map3
                  (fun id name species -> (id, name, species))
                  (Decode.column 0 (Decode.int ()))
                  (Decode.column 1 (Decode.string ()))
                  (Decode.column 2 (Decode.string ())))
               "1,Atlas,Cat"
            = Ok [ (1, "Atlas", "Cat") ]) );
      (* --------------------------------------------------------------- *)
      (* one_of                                                          *)
      (* --------------------------------------------------------------- *)
      ( "testOneOf_decodesAValue",
        fun () ->
          assert_eq ~show:(show_result string_of_int) ~expected:(Ok [ 1 ])
            (Decode.decode_csv Decode.No_field_names (Decode.one_of (Decode.int ()) []) "1") );
      ( "testOneOf_usesAFallback",
        fun () ->
          let decoder = Decode.one_of (Decode.map Option.some (Decode.int ())) [ Decode.succeed None ] in
          assert_true (Decode.decode_csv Decode.No_field_names decoder "a" = Ok [ None ]) );
      ( "testOneOf_givesAllTheErrorsIfAllTheDecodersFail",
        fun () ->
          assert_eq ~show:(show_result show_unit)
            ~expected:
              (Error
                 (Decode.Decoding_errors
                    [
                      Decode.One_of_decoding_error
                        ( 0,
                          [
                            Decode.Field_decoding_error (0, Decode.Only_column, Decode.Failure "ONE");
                            Decode.Field_decoding_error (0, Decode.Only_column, Decode.Failure "TWO");
                            Decode.Field_decoding_error (0, Decode.Only_column, Decode.Failure "THREE");
                          ] );
                    ]))
            (Decode.decode_csv Decode.No_field_names
               (Decode.one_of (Decode.fail "ONE") [ Decode.fail "TWO"; Decode.fail "THREE" ])
               "a") );
      (* --------------------------------------------------------------- *)
      (* succeed                                                         *)
      (* --------------------------------------------------------------- *)
      ( "testSucceed_ignoresTheValues",
        fun () ->
          assert_eq ~show:(show_result show_unit) ~expected:(Ok [ () ])
            (Decode.decode_csv Decode.No_field_names (Decode.succeed ()) "a") );
      ( "testSucceed_providesOneValueForEachRow",
        fun () ->
          assert_eq ~show:(show_result show_unit) ~expected:(Ok [ (); () ])
            (Decode.decode_csv Decode.No_field_names (Decode.succeed ()) "a\r\nb") );
      (* --------------------------------------------------------------- *)
      (* fail                                                            *)
      (* --------------------------------------------------------------- *)
      ( "testFail_ignoresTheValues",
        fun () ->
          assert_eq ~show:(show_result show_unit)
            ~expected:
              (Error
                 (Decode.Decoding_errors
                    [ Decode.Field_decoding_error (0, Decode.Only_column, Decode.Failure "a nice description") ]))
            (Decode.decode_csv Decode.No_field_names (Decode.fail "a nice description") "a") );
      ( "testFail_failsOnEveryRowWhereItsAttempted",
        fun () ->
          assert_eq ~show:(show_result show_unit)
            ~expected:
              (Error
                 (Decode.Decoding_errors
                    [
                      Decode.Field_decoding_error (0, Decode.Only_column, Decode.Failure "a nice description");
                      Decode.Field_decoding_error (1, Decode.Only_column, Decode.Failure "a nice description");
                    ]))
            (Decode.decode_csv Decode.No_field_names (Decode.fail "a nice description") "a\r\nb") );
      (* --------------------------------------------------------------- *)
      (* and_then -- for validation                                      *)
      (* --------------------------------------------------------------- *)
      ( "testAndThen_allowsPositiveIntegers",
        fun () ->
          let positive_integer =
            Decode.and_then
              (fun value ->
                if value > 0 then Decode.succeed value else Decode.fail "Only positive integers are allowed!")
              (Decode.int ())
          in
          assert_eq ~show:(show_result string_of_int) ~expected:(Ok [ 1 ])
            (Decode.decode_csv Decode.No_field_names positive_integer "1") );
      ( "testAndThen_disallowsNegativeIntegers",
        fun () ->
          let positive_integer =
            Decode.and_then
              (fun value ->
                if value > 0 then Decode.succeed value else Decode.fail "Only positive integers are allowed!")
              (Decode.int ())
          in
          assert_eq ~show:(show_result string_of_int)
            ~expected:
              (Error
                 (Decode.Decoding_errors
                    [
                      Decode.Field_decoding_error
                        (0, Decode.Only_column, Decode.Failure "Only positive integers are allowed!");
                    ]))
            (Decode.decode_csv Decode.No_field_names positive_integer "-1") );
      (* --------------------------------------------------------------- *)
      (* and_then -- for fields depending on each other                  *)
      (* --------------------------------------------------------------- *)
      ( "testAndThen_getTheSecondColumn",
        fun () ->
          let follow_the_pointer =
            Decode.column 0 (Decode.int ()) |> Decode.and_then (fun col -> Decode.column col (Decode.string ()))
          in
          assert_eq ~show:(show_result quoted) ~expected:(Ok [ "a" ])
            (Decode.decode_csv Decode.No_field_names follow_the_pointer "1,a,b") );
      ( "testAndThen_getTheThirdColumn",
        fun () ->
          let follow_the_pointer =
            Decode.column 0 (Decode.int ()) |> Decode.and_then (fun col -> Decode.column col (Decode.string ()))
          in
          assert_eq ~show:(show_result quoted) ~expected:(Ok [ "b" ])
            (Decode.decode_csv Decode.No_field_names follow_the_pointer "2,a,b") );
      ( "testAndThen_hasAReasonableErrorMessageForMissingAColumn",
        fun () ->
          let follow_the_pointer =
            Decode.column 0 (Decode.int ()) |> Decode.and_then (fun col -> Decode.column col (Decode.string ()))
          in
          assert_eq ~show:(show_result quoted)
            ~expected:
              (Error
                 (Decode.Decoding_errors
                    [ Decode.Field_decoding_error (0, Decode.Column 3, Decode.Column_not_found 3) ]))
            (Decode.decode_csv Decode.No_field_names follow_the_pointer "3,a,b") );
      (* --------------------------------------------------------------- *)
      (* from_result                                                     *)
      (* --------------------------------------------------------------- *)
      ( "testFromResult_succeedsWhenTheFunctionReturnsOk",
        fun () ->
          let hex = Decode.string () |> Decode.and_then (fun s -> Decode.from_result (hex_from_string s)) in
          assert_eq ~show:(show_result string_of_int) ~expected:(Ok [ 255 ])
            (Decode.decode_csv Decode.No_field_names hex "ff") );
      ( "testFromResult_failsWhenTheFunctionReturnsErr",
        fun () ->
          let hex = Decode.string () |> Decode.and_then (fun s -> Decode.from_result (hex_from_string s)) in
          assert_eq ~show:(show_result string_of_int)
            ~expected:
              (Error
                 (Decode.Decoding_errors
                    [
                      Decode.Field_decoding_error
                        ( 0,
                          Decode.Only_column,
                          Decode.Failure
                            "\"banana\" is not a valid hexadecimal string because n is not a valid hexadecimal character."
                        );
                    ]))
            (Decode.decode_csv Decode.No_field_names hex "banana") );
      (* --------------------------------------------------------------- *)
      (* from_option                                                     *)
      (* --------------------------------------------------------------- *)
      ( "testFromOption_succeedsWhenTheFunctionReturnsSome",
        fun () ->
          let my_int =
            Decode.string ()
            |> Decode.and_then (fun s -> Decode.from_option "Expected an int" (Util_parse.int_of_string_opt s))
          in
          assert_eq ~show:(show_result string_of_int) ~expected:(Ok [ 123 ])
            (Decode.decode_csv Decode.No_field_names my_int "123") );
      ( "testFromOption_failsWhenTheFunctionReturnsNone",
        fun () ->
          let my_int =
            Decode.string ()
            |> Decode.and_then (fun s -> Decode.from_option "Expected an int" (Util_parse.int_of_string_opt s))
          in
          assert_eq ~show:(show_result string_of_int)
            ~expected:
              (Error
                 (Decode.Decoding_errors
                    [ Decode.Field_decoding_error (0, Decode.Only_column, Decode.Failure "Expected an int") ]))
            (Decode.decode_csv Decode.No_field_names my_int "banana") );
      (* --------------------------------------------------------------- *)
      (* error_to_string                                                 *)
      (* --------------------------------------------------------------- *)
      ( "testErrorToString_groupsSimpleErrors",
        fun () ->
          assert_eq ~show:(show_message_result string_of_int) ~expected:(Error "There was a problem on rows 0\xe2\x80\x932, column 0 (the only column present): I could not parse an int from `a`.")
            (Decode.decode_csv Decode.No_field_names (Decode.int ()) "a\na\na"
            |> Result.map_error Decode.error_to_string) );
      ( "testErrorToString_groupsSimpleErrorsInMoreComplexSettings",
        fun () ->
          assert_eq ~show:(show_message_result string_of_int)
            ~expected:
              (Error
                 "I saw 3 problems while decoding this CSV:\n\nThere was a problem on rows 0 and 1, column 0 (the only column present): I could not parse an int from `a`.\n\nThere was a problem on row 2, column 0 (the only column present): I could not parse an int from `b`.\n\nThere was a problem on rows 3 and 4, column 0 (the only column present): I could not parse an int from `a`.")
            (Decode.decode_csv Decode.No_field_names (Decode.int ()) "a\na\nb\na\na"
            |> Result.map_error Decode.error_to_string) );
      ( "testErrorToString_worksWithMap2",
        fun () ->
          assert_true
            (Decode.decode_csv Decode.Field_names_from_first_row
               (Decode.map2 (fun a b -> (a, b)) (Decode.field "foo" (Decode.int ())) (Decode.field "bar" (Decode.int ())))
               "foo,bar\na,2\na,b\na,c"
            |> Result.map_error Decode.error_to_string
            = Error
                "I saw 3 problems while decoding this CSV:\n\nThere was a problem on rows 1\xe2\x80\x933, in the `foo` field (column 0): I could not parse an int from `a`.\n\nThere was a problem on row 2, in the `bar` field (column 1): I could not parse an int from `b`.\n\nThere was a problem on row 3, in the `bar` field (column 1): I could not parse an int from `c`.")
      );
      ( "testErrorToString_worksWithOneOf",
        fun () ->
          assert_eq ~show:(show_message_result string_of_float)
            ~expected:
              (Error
                 "There was a problem on row 0 - all of the following decoders failed, but at least one must succeed:\n  (1) column 0 (the only column present): I could not parse an int from `a`.\n  (2) column 0 (the only column present): I could not parse a float from `a`.")
            (Decode.decode_csv Decode.No_field_names
               (Decode.one_of (Decode.map float_of_int (Decode.int ())) [ Decode.float () ])
               "a\n1\n1.2"
            |> Result.map_error Decode.error_to_string) );
      ( "testErrorToString_worksWithNestedOneOf",
        fun () ->
          assert_eq ~show:(show_message_result string_of_float)
            ~expected:
              (Error
                 "There was a problem on row 0 - all of the following decoders failed, but at least one must succeed:\n  (1) column 0 (the only column present): I could not parse a float from `a`.\n  (2) column 0 (the only column present): I could not parse an int from `a`.\n  (3) column 0 (the only column present): I could not parse a float from `a`.")
            (Decode.decode_csv Decode.No_field_names
               (Decode.one_of (Decode.float ())
                  [ Decode.one_of (Decode.map float_of_int (Decode.int ())) [ Decode.float () ] ])
               "a\n1\n1.2"
            |> Result.map_error Decode.error_to_string) );
      ( "testErrorToString_worksWithComplexDecoder",
        fun () ->
          assert_true
            (Decode.decode_csv Decode.Field_names_from_first_row
               (Decode.map2
                  (fun a b -> (a, b))
                  (Decode.one_of
                     (Decode.field "foo" (Decode.int ()))
                     [ Decode.field "bar" (Decode.map round (Decode.float ())) ])
                  (Decode.field "bar" (Decode.int ())))
               "foo,bar\na,2\na,b\na,c"
            |> Result.map_error Decode.error_to_string
            = Error
                "I saw 4 problems while decoding this CSV:\n\nThere was a problem on row 2, in the `bar` field (column 1): I could not parse an int from `b`.\n\nThere was a problem on row 2 - all of the following decoders failed, but at least one must succeed:\n  (1) in the `foo` field (column 0): I could not parse an int from `a`.\n  (2) in the `bar` field (column 1): I could not parse a float from `b`.\n\nThere was a problem on row 3, in the `bar` field (column 1): I could not parse an int from `c`.\n\nThere was a problem on row 3 - all of the following decoders failed, but at least one must succeed:\n  (1) in the `foo` field (column 0): I could not parse an int from `a`.\n  (2) in the `bar` field (column 1): I could not parse a float from `c`.")
      );
      (* --------------------------------------------------------------- *)
      (* available_fields                                                *)
      (* --------------------------------------------------------------- *)
      ( "testAvailableFields_returnsHeaderRowInOrder",
        fun () ->
          assert_true
            (Decode.decode_csv Decode.Field_names_from_first_row (Decode.available_fields ()) "foo,bar\na,a\na,b\na,c"
            = Ok [ [ "foo"; "bar" ]; [ "foo"; "bar" ]; [ "foo"; "bar" ] ]) );
      ( "testAvailableFields_allowsConditionalDecodingBasedOnHeaderRow",
        fun () ->
          assert_eq ~show:(show_result quoted) ~expected:(Ok [ "a"; "b"; "c" ])
            (Decode.decode_csv Decode.Field_names_from_first_row
               (Decode.available_fields ()
               |> Decode.and_then (fun headers ->
                      if List.mem "bar" headers then Decode.field "bar" (Decode.string ())
                      else Decode.field "foo" (Decode.string ())))
               "foo,bar\na,a\na,b\na,c") );
      ( "testAvailableFields_returnsConfiguredFields",
        fun () ->
          assert_true
            (Decode.decode_csv (Decode.Custom_field_names [ "Foo"; "Bar" ]) (Decode.available_fields ()) "\n"
            = Ok [ [ "Foo"; "Bar" ] ]) );
      ( "testAvailableFields_failsWhenNoNamedFields",
        fun () ->
          assert_true
            (Decode.decode_csv Decode.No_field_names (Decode.available_fields ()) "\n"
             |> Result.map_error Decode.error_to_string
            = Error "Asked for available fields, but none were provided") );
    ] )
