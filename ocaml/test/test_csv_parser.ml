open Motorsport_cli
open Harness
module Parser = Util_csv_parser

(* ------------------------------------------------------------------------- *)
(* Configurations                                                             *)
(* ------------------------------------------------------------------------- *)

type config = {
  row_separator : string;
  field_separator : char;
}

let configurations =
  [
    { row_separator = "\r\n"; field_separator = ',' } (* CRLF CSV (US locale) *);
    { row_separator = "\r\n"; field_separator = ';' } (* CRLF CSV (EU locale, semicolon) *);
    { row_separator = "\n"; field_separator = ',' } (* LF-only CSV *);
    { row_separator = "\r\n"; field_separator = '\t' } (* CRLF TSV *);
    { row_separator = "\n"; field_separator = '\t' } (* LF-only TSV *);
  ]

(* ------------------------------------------------------------------------- *)
(* Helpers                                                                    *)
(* ------------------------------------------------------------------------- *)

let show = function
  | Ok rows -> "Ok [" ^ String.concat "; " (List.map (fun r -> "[" ^ String.concat "; " r ^ "]") rows) ^ "]"
  | Error p -> "Error " ^ Parser.problem_to_string p

let encode config rows =
  let sep = String.make 1 config.field_separator in
  rows |> List.map (String.concat sep) |> String.concat config.row_separator

let expect_round_trip config rows =
  assert_eq ~show ~expected:(Ok rows) (Parser.parse ~field_separator:config.field_separator (encode config rows))

let for_each_configuration body () = List.iter body configurations

(* ------------------------------------------------------------------------- *)
(* Tests                                                                      *)
(* ------------------------------------------------------------------------- *)

let suite =
  ( "Util.Csv.TestParser",
    [
      ("testSingleValue", for_each_configuration (fun config -> expect_round_trip config [ [ "a" ] ]));
      ("testTwoFields", for_each_configuration (fun config -> expect_round_trip config [ [ "a"; "b" ] ]));
      ("testTwoRows", for_each_configuration (fun config -> expect_round_trip config [ [ "a" ]; [ "b" ] ]));
      ( "testTwoRowsOfTwoFields",
        for_each_configuration (fun config -> expect_round_trip config [ [ "a"; "b" ]; [ "c"; "d" ] ]) );
      ("testBlankFields", for_each_configuration (fun config -> expect_round_trip config [ [ ""; ""; "" ] ]));
      ( "testOnlyHalfOfRowSeparator",
        for_each_configuration (fun config ->
            if String.length config.row_separator <= 1 then (* not relevant here *) ()
            else
              let first = String.make 1 config.row_separator.[0] in
              assert_eq ~show ~expected:(Ok [ [ first ] ]) (Parser.parse ~field_separator:config.field_separator first))
      );
      (* quoted values *)
      ( "testQuotedSingleValues",
        for_each_configuration (fun config ->
            assert_eq ~show ~expected:(Ok [ [ "a" ] ])
              (Parser.parse ~field_separator:config.field_separator "\"a\"")) );
      ( "testQuotedRowSeparators",
        for_each_configuration (fun config ->
            assert_eq ~show
              ~expected:(Ok [ [ config.row_separator ] ])
              (Parser.parse ~field_separator:config.field_separator ("\"" ^ config.row_separator ^ "\""))) );
      ( "testQuotedFieldSeparators",
        for_each_configuration (fun config ->
            let sep = String.make 1 config.field_separator in
            assert_eq ~show ~expected:(Ok [ [ sep ] ])
              (Parser.parse ~field_separator:config.field_separator ("\"" ^ sep ^ "\""))) );
      ( "testQuotedQuotes",
        for_each_configuration (fun config ->
            assert_eq ~show
              ~expected:(Ok [ [ "\"" ] ])
              (Parser.parse ~field_separator:config.field_separator "\"\"\"\"")) );
      ( "testTwoQuotedValuesInARow",
        for_each_configuration (fun config ->
            let sep = String.make 1 config.field_separator in
            assert_eq ~show
              ~expected:(Ok [ [ "a"; "b" ] ])
              (Parser.parse ~field_separator:config.field_separator ("\"a\"" ^ sep ^ "\"b\""))) );
      ( "testTwoRowsWithQuotedValues",
        for_each_configuration (fun config ->
            assert_eq ~show
              ~expected:(Ok [ [ "a" ]; [ "b" ] ])
              (Parser.parse ~field_separator:config.field_separator ("\"a\"" ^ config.row_separator ^ "\"b\""))) );
      ( (* https://github.com/BrianHicks/elm-csv/issues/8 *)
        "testTrailingNewlineShouldBeIgnored",
        for_each_configuration (fun config ->
            let rows =
              [ [ "Country"; "Population" ]; [ "Agentina"; "44361150" ]; [ "Brazil"; "212652000" ] ]
            in
            assert_eq ~show ~expected:(Ok rows)
              (Parser.parse ~field_separator:config.field_separator (encode config rows ^ config.row_separator))) );
      ( (* https://github.com/BrianHicks/elm-csv/issues/24 *)
        "testTrailingNewlineAfterQuotedFieldShouldBeIgnored",
        for_each_configuration (fun config ->
            assert_eq ~show
              ~expected:(Ok [ [ "val" ] ])
              (Parser.parse ~field_separator:config.field_separator ("\"val\"" ^ config.row_separator))) );
      (* errors *)
      ( "testNotEndingAQuotedValueIsAnError",
        for_each_configuration (fun config ->
            assert_eq ~show
              ~expected:(Error (Parser.Source_ended_without_closing_quote 1))
              (Parser.parse ~field_separator:config.field_separator "\"a")) );
      ( "testAdditionalCharactersAfterClosingQuoteBeforeFieldSeparatorIsAnError",
        for_each_configuration (fun config ->
            assert_eq ~show
              ~expected:(Error (Parser.Additional_characters_after_closing_quote 1))
              (Parser.parse ~field_separator:config.field_separator ("\"a\"b" ^ config.row_separator))) );
      ( "testAdditionalCharactersAfterClosingQuoteBeforeRowSeparatorIsAnError",
        for_each_configuration (fun config ->
            assert_eq ~show
              ~expected:(Error (Parser.Additional_characters_after_closing_quote 1))
              (Parser.parse ~field_separator:config.field_separator
                 ("\"a\"b" ^ String.make 1 config.field_separator))) );
    ] )
