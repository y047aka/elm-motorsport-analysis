open Motorsport_cli
open Harness
module Hour_clock = Util_hour_clock

let suite =
  ( "Util.TestHourClock",
    [
      ( "testParseValidHms",
        fun () ->
          match Hour_clock.parse "11:02:03.456" with
          | Ok h -> assert_true (Hour_clock.ms_since_midnight h = 39723456)
          | Error _ -> assert_true false );
      ( "testParseEmptyIsErr",
        fun () ->
          match Hour_clock.parse "" with Error raw -> assert_true (raw = "") | Ok _ -> assert_true false );
      ( (* M:SS is not a time-of-day, so an error is expected *)
        "testParseTwoComponentRejected",
        fun () ->
          match Hour_clock.parse "3:38.404" with Error _ -> assert_true true | Ok _ -> assert_true false );
      ( "testParseTwentyFourHoursRejected",
        fun () ->
          match Hour_clock.parse "24:00:00.000" with Error _ -> assert_true true | Ok _ -> assert_true false );
      ( "testParseGarbageReturnsRaw",
        fun () ->
          match Hour_clock.parse "not-a-time" with
          | Error raw -> assert_true (raw = "not-a-time")
          | Ok _ -> assert_true false );
      ( "testFormatProducesZeroPaddedHms",
        fun () ->
          match Hour_clock.parse "00:00:00.036" with
          | Ok h -> assert_true (Hour_clock.format h = "00:00:00.036")
          | Error _ -> assert_true false );
      ( "testFormatLargeHour",
        fun () ->
          match Hour_clock.parse "23:59:00.000" with
          | Ok h -> assert_true (Hour_clock.format h = "23:59:00.000")
          | Error _ -> assert_true false );
      ( (* 14:02:00.000 - 2:00.000 = 14:00:00.000 = 50400000 ms *)
        "testOffsetFromBasic",
        fun () ->
          match Hour_clock.parse "14:02:00.000" with
          | Ok h -> assert_true (Hour_clock.offset_from h 120000 = 50400000)
          | Error _ -> assert_true false );
      ( (* race start 16:00:00.000, after 8h elapsed hour = 00:00:00.000
           (0 - 8h) mod 24h = 16h = 57600000 ms *)
        "testOffsetFromMidnightWrap",
        fun () ->
          match Hour_clock.parse "00:00:00.000" with
          | Ok h ->
            let elapsed = 8 * 3600 * 1000 in
            assert_true (Hour_clock.offset_from h elapsed = 57600000)
          | Error _ -> assert_true false );
      ( (* 23:59:00.000 - 1:00.000 = 23:58:00.000
           0:01:00.000 - 3:00.000 = -2:00 mod 24h = 23:58:00.000 (wrap-aware) *)
        "testOffsetFromSameWallClockBeforeAndAfterMidnight",
        fun () ->
          match (Hour_clock.parse "23:59:00.000", Hour_clock.parse "0:01:00.000") with
          | Ok b, Ok a -> assert_true (Hour_clock.offset_from b 60000 = Hour_clock.offset_from a 180000)
          | _ -> assert_true false );
    ] )
