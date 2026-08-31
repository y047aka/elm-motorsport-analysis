open Motorsport_cli
open Harness
module Duration = Util_duration

let suite =
  ( "Util.TestDuration",
    [
      ("testFromStringEmpty", fun () -> assert_true (Duration.of_string "" = None));
      ( "testFromStringSecondsOnly",
        fun () -> assert_true (Duration.of_string "23.155" = Some (Duration.of_millis 23155)) );
      ( "testFromStringMinutesSeconds",
        fun () -> assert_true (Duration.of_string "1:35.365" = Some (Duration.of_millis 95365)) );
      ( "testFromStringHoursMinutesSeconds",
        fun () -> assert_true (Duration.of_string "1:02:05.001" = Some (Duration.of_millis 3725001)) );
      ("testFromStringInvalid", fun () -> assert_true (Duration.of_string "not-a-duration" = None));
      ("testFormatSecondsOnly", fun () -> assert_true (Duration.format (Duration.of_millis 23155) = "23.155"));
      ( "testFormatStripsLeadingZeroHour",
        fun () -> assert_true (Duration.format (Duration.of_millis 101031) = "1:41.031") );
      ( "testFormatStripsLeadingZeroHourAndMinute",
        fun () -> assert_true (Duration.format (Duration.of_millis 48666) = "48.666") );
      ( "testFormatHoursMinutesSeconds",
        fun () -> assert_true (Duration.format (Duration.of_millis 3725001) = "1:02:05.001") );
      ("testToStringInstance", fun () -> assert_true (Duration.to_string (Duration.of_millis 95365) = "1:35.365"));
      ( "testAdd",
        fun () ->
          let a = Duration.of_millis 30000 in
          let b = Duration.of_millis 60000 in
          assert_true (Duration.add a b = Duration.of_millis 90000) );
      ("testZero", fun () -> assert_true (Duration.zero = Duration.of_millis 0));
    ] )
