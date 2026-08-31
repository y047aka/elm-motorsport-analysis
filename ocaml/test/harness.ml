(** What [Assert] and the [@Test] annotation give the Flix tests, spelled out. *)

exception Assertion_failed of string

let assert_true condition = if not condition then raise (Assertion_failed "expected true")

let assert_eq ?(show = fun _ -> "<value>") ~expected actual =
  if expected <> actual then
    raise (Assertion_failed (Printf.sprintf "expected %s but got %s" (show expected) (show actual)))

let unreachable () = raise (Assertion_failed "unreachable branch taken")

let run suites =
  let total = ref 0 and failures = ref 0 in
  List.iter
    (fun (suite, tests) ->
      List.iter
        (fun (name, body) ->
          incr total;
          match body () with
          | () -> ()
          | exception Assertion_failed message ->
            incr failures;
            Printf.eprintf "FAIL %s.%s: %s\n" suite name message
          | exception e ->
            incr failures;
            Printf.eprintf "ERROR %s.%s: %s\n" suite name (Printexc.to_string e))
        tests)
    suites;
  Printf.printf "%d tests, %d failures\n" !total !failures;
  if !failures > 0 then exit 1
