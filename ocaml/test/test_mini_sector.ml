open Motorsport_cli
open Harness
module Mini_sector = Motorsport_mini_sector

let suite =
  ( "Motorsport.TestMiniSector",
    [
      ( (* The constructors A7_1 / A8_1 must map to the hyphenated CSV columns
           A7-1_* / A8-1_*. *)
        "testCsvNamesPreserveHyphens",
        fun () ->
          assert_true (Mini_sector.csv_name Mini_sector.A7_1 = "A7-1");
          assert_true (Mini_sector.csv_name Mini_sector.A8_1 = "A8-1") );
      ( (* JSON keys keep the underscore (matches Elm Motorsport.Lap.MiniSectors). *)
        "testJsonKeysPreserveUnderscores",
        fun () ->
          assert_true (Mini_sector.json_key Mini_sector.A7_1 = "a7_1");
          assert_true (Mini_sector.json_key Mini_sector.A8_1 = "a8_1") );
      ( "testAllIdsHaveDistinctJsonKeys",
        fun () ->
          let keys = List.map Mini_sector.json_key Mini_sector.all in
          assert_true (List.length (List.sort_uniq compare keys) = 15) );
    ] )
